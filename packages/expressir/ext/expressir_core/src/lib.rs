//! Ruby bridge for expressir-core: exposes the Rust parse + model
//! extraction pipeline to the expressir gem.
//!
//! Two entry points:
//! - `parse_to_model_hash` — the wire JSON string (tooling, parity runs)
//! - `parse_to_model` — the hydrated model, built by walking the wire
//!   JSON definition once and constructing each node through
//!   `Serializable.instantiate` (lutaml-model's fast bulk constructor).
//!   Skips the JSON string, `JSON.parse`, and the generic from_hash
//!   mapping machinery.

use std::collections::HashMap;
use std::sync::mpsc::Receiver;
use std::sync::Mutex;

use expressir_rs::batch::{self, BatchOutcome};
use expressir_rs::compiled_set::{CompiledFile, CompiledSet};
use expressir_rs::ParsedTree;
use magnus::{function, method};
use magnus::prelude::*;
use magnus::typed_data::DataTypeBuilder;
use magnus::value::Lazy;
use magnus::IntoValue;
use magnus::{DataType, DataTypeFunctions, Error, RArray, RClass, RHash, RModule, Ruby, TypedData};
use serde_json::Value as Wire;

fn parse_error(ruby: &Ruby, e: expressir_rs::model_json::ModelJsonError) -> Error {
    Error::new(
        ruby.exception_runtime_error(),
        format!("expressir-core: parse error: {e:?}"),
    )
}

fn model_json(ruby: &Ruby, source: String, path: String) -> Result<String, Error> {
    let tree = ParsedTree::parse(&source).map_err(|e| {
        Error::new(
            ruby.exception_runtime_error(),
            format!("expressir-core: parse error: {e:?}"),
        )
    })?;
    let value = tree.to_model_json(&path).map_err(|e| parse_error(ruby, e))?;
    serde_json::to_string(&value).map_err(|e| {
        Error::new(
            ruby.exception_runtime_error(),
            format!("expressir-core: serialize error: {e}"),
        )
    })
}

/// The remark scanner (issue #20): each unit mirrors
/// `Expressir::Express::RemarkScanner::Remark` — position,
/// end_position, line, text, tag (nil when untagged), format.
fn scan_remarks(ruby: &Ruby, source: String) -> Result<magnus::Value, Error> {
    let units = expressir_rs::remark::scan(&source);
    let array = ruby.ary_new_capa(units.len());
    for unit in &units {
        let hash = ruby.hash_new();
        hash.aset(
            ruby.sym_new("position"),
            ruby.integer_from_i64(unit.position as i64),
        )?;
        hash.aset(
            ruby.sym_new("end_position"),
            ruby.integer_from_i64(unit.end_position as i64),
        )?;
        hash.aset(ruby.sym_new("line"), ruby.integer_from_i64(unit.line as i64))?;
        hash.aset(ruby.sym_new("text"), ruby_str(ruby, &unit.text));
        hash.aset(
            ruby.sym_new("tag"),
            match unit.tag.as_deref() {
                Some(tag) => ruby_str(ruby, tag),
                None => ruby.qnil().as_value(),
            },
        );
        hash.aset(ruby.sym_new("format"), ruby_str(ruby, unit.format));
        array.push(hash)?;
    }
    Ok(array.as_value())
}

/// Resolves `Expressir::Model::*` classes by their wire `_class` name,
/// caching each lookup (the class set is closed).
#[derive(Default)]
struct ClassCache {
    classes: HashMap<String, RClass>,
}

impl ClassCache {
    fn resolve(&mut self, ruby: &Ruby, name: &str) -> Result<RClass, Error> {
        if let Some(klass) = self.classes.get(name) {
            return Ok(*klass);
        }

        let short = name.strip_prefix("Expressir::Model::").ok_or_else(|| {
            Error::new(
                ruby.exception_runtime_error(),
                format!("expressir-core: unknown model class {name:?}"),
            )
        })?;
        let mut current = ruby
            .class_object()
            .const_get::<_, RModule>("Expressir")?
            .const_get::<_, RModule>("Model")?;
        let segments: Vec<&str> = short.split("::").collect();
        let last = segments.len() - 1;
        for (i, segment) in segments.iter().enumerate() {
            let value = current
                .const_get::<_, magnus::Value>(segment.to_string())
                .map_err(|e| {
                    Error::new(
                        ruby.exception_runtime_error(),
                        format!("expressir-core: unknown model class {name:?}: {e}"),
                    )
                })?;
            if i == last {
                let klass = RClass::from_value(value).ok_or_else(|| {
                    Error::new(
                        ruby.exception_runtime_error(),
                        format!("expressir-core: {name:?} is not a class"),
                    )
                })?;
                self.classes.insert(name.to_string(), klass);
                return Ok(klass);
            }
            current = RModule::from_value(value).ok_or_else(|| {
                Error::new(
                    ruby.exception_runtime_error(),
                    format!("expressir-core: {name:?} is not a module"),
                )
            })?;
        }
        unreachable!()
    }
}

/// Live handle to a running batch compile: the outcomes channel plus
/// the per-stream class cache and the wire values retained for
/// artifact assembly. `next` blocks until a worker delivers; workers
/// are Rust threads, so they progress while Ruby waits.
#[derive(DataTypeFunctions)]
struct BatchStream {
    rx: Receiver<BatchOutcome>,
    cache: Mutex<ClassCache>,
    wires: Mutex<Vec<(String, Wire)>>,
    /// Wire paths in job order — the artifact layout must be
    /// deterministic regardless of completion order.
    order: Mutex<Vec<String>>,
}

// SAFETY: BatchStream never crosses threads itself; Send is required by
// magnus to expose methods, and every access happens on the Ruby thread
// that owns the stream.
unsafe impl Send for BatchStream {}

unsafe impl TypedData for BatchStream {
    fn class(ruby: &Ruby) -> RClass {
        static CLASS: Lazy<RClass> = Lazy::new(|ruby| {
            let class = ruby
                .class_object()
                .const_get::<_, RModule>("Expressir")
                .and_then(|m| m.const_get::<_, RModule>("Core"))
                .and_then(|m| m.const_get::<_, RClass>("BatchStream"))
                .expect("Expressir::Core::BatchStream defined in init");
            class.undef_default_alloc_func();
            class
        });
        ruby.get_inner(&CLASS)
    }

    fn data_type() -> &'static DataType {
        static DATA_TYPE: DataType =
            DataTypeBuilder::<BatchStream>::new(c"Expressir::Core::BatchStream").build();
        &DATA_TYPE
    }
}

fn batch_start(ruby: &Ruby, jobs: RArray, workers: usize) -> Result<BatchStream, Error> {
    let mut parsed: Vec<(String, String)> = Vec::with_capacity(jobs.len());
    for index in 0..jobs.len() {
        let job = jobs.entry(index as isize)?;
        let pair = RArray::from_value(job).ok_or_else(|| {
            Error::new(
                ruby.exception_arg_error(),
                "jobs must be [read_path, wire_path] pairs",
            )
        })?;
        let read_path: String = pair.entry(0)?;
        let wire_path: String = pair.entry(1)?;
        parsed.push((read_path, wire_path));
    }
    let order = parsed.iter().map(|(_, wire)| wire.clone()).collect();
    let rx = batch::parse_batch(parsed, workers);
    Ok(BatchStream {
        rx,
        cache: Mutex::new(ClassCache::default()),
        wires: Mutex::new(Vec::new()),
        order: Mutex::new(order),
    })
}

/// Write the compiled-set artifact from this stream's retained wires:
/// `read_paths` maps wire_path → physical source for digesting.
fn batch_write_set(
    ruby: &Ruby,
    stream: &BatchStream,
    out_path: String,
    read_paths: RHash,
    expressir_version: String,
) -> Result<magnus::Value, Error> {
    let wires = stream.wires.lock().expect("wires").clone();
    let order = stream.order.lock().expect("order").clone();
    let position: HashMap<String, usize> =
        order.iter().enumerate().map(|(i, p)| (p.clone(), i)).collect();
    let mut wires = wires;
    wires.sort_by_key(|(wire_path, _)| position.get(wire_path).copied().unwrap_or(usize::MAX));

    let mut files = Vec::with_capacity(wires.len());
    for (wire_path, wire) in wires {
        let read_path: Option<String> = read_paths
            .fetch(ruby.str_new(&wire_path))
            .map_err(|e| Error::new(ruby.exception_arg_error(), e.to_string()))?;
        let source_sha = read_path
            .as_deref()
            .map(compiled_set_file_sha)
            .unwrap_or_default();
        let wire_json = serde_json::to_string(&wire).map_err(|e| {
            Error::new(
                ruby.exception_runtime_error(),
                format!("wire encode {wire_path}: {e}"),
            )
        })?;
        files.push(CompiledFile {
            wire_path,
            source_sha,
            wire_json,
        });
    }
    let set = CompiledSet::build(files, &expressir_version, &expressir_rs::grammar_digest());
    set.write_to(&out_path).map_err(|e| {
        Error::new(
            ruby.exception_io_error(),
            format!("compiled set {out_path}: {e}"),
        )
    })?;
    Ok(ruby.str_new(&set.header.set_digest).as_value())
}

fn compiled_set_file_sha(path: &str) -> String {
    expressir_rs::compiled_set::file_sha256(path)
}

/// `[wire_path, model, nil]` / `[wire_path, nil, message]`, or nil when
/// the queue has drained.
fn batch_next(ruby: &Ruby, stream: &BatchStream) -> Result<magnus::Value, Error> {
    let outcome = stream.rx.recv();
    let Ok(outcome) = outcome else {
        return Ok(ruby.qnil().as_value());
    };
    let BatchOutcome { path, result } = outcome;
    let triple = RArray::with_capacity(3);
    triple.push(ruby.str_new(&path))?;
    match result {
        Ok(wire) => {
            stream
                .wires
                .lock()
                .expect("wires")
                .push((path.clone(), wire.clone()));
            let mut cache = stream.cache.lock().expect("class cache");
            let model = value_to_ruby(ruby, &mut cache, &wire)?;
            triple.push(model)?;
            triple.push(ruby.qnil())?;
        }
        Err(message) => {
            triple.push(ruby.qnil())?;
            triple.push(ruby.str_new(&message))?;
        }
    }
    Ok(triple.as_value())
}

/// Reader over a compiled-set artifact: ordered, lazy — each `next`
/// hydrates one file's wire model through the shared class cache.
#[derive(DataTypeFunctions)]
struct SetReader {
    set: CompiledSet,
    index: Mutex<usize>,
    cache: Mutex<ClassCache>,
}

// SAFETY: only ever touched from the owning Ruby thread.
unsafe impl Send for SetReader {}

unsafe impl TypedData for SetReader {
    fn class(ruby: &Ruby) -> RClass {
        static CLASS: Lazy<RClass> = Lazy::new(|ruby| {
            let class = ruby
                .class_object()
                .const_get::<_, RModule>("Expressir")
                .and_then(|m| m.const_get::<_, RModule>("Core"))
                .and_then(|m| m.const_get::<_, RClass>("Set"))
                .expect("Expressir::Core::Set defined in init");
            class.undef_default_alloc_func();
            class
        });
        ruby.get_inner(&CLASS)
    }

    fn data_type() -> &'static DataType {
        static DATA_TYPE: DataType =
            DataTypeBuilder::<SetReader>::new(c"Expressir::Core::Set").build();
        &DATA_TYPE
    }
}

fn set_open(_ruby: &Ruby, path: String) -> Result<SetReader, Error> {
    let set = CompiledSet::read_from(&path).map_err(|e| {
        Error::new(
            _ruby.exception_runtime_error(),
            format!("compiled set {path}: {e}"),
        )
    })?;
    Ok(SetReader {
        set,
        index: Mutex::new(0),
        cache: Mutex::new(ClassCache::default()),
    })
}

fn set_digest(ruby: &Ruby, reader: &SetReader) -> Result<magnus::Value, Error> {
    Ok(ruby.str_new(&reader.set.header.set_digest).as_value())
}

fn set_count(_ruby: &Ruby, reader: &SetReader) -> usize {
    reader.set.files.len()
}

/// Every wire path in the artifact, in artifact order — no hydration.
fn set_wire_paths(_ruby: &Ruby, reader: &SetReader) -> Result<magnus::Value, Error> {
    let paths = RArray::with_capacity(reader.set.files.len());
    for file in &reader.set.files {
        paths.push(ruby_str(_ruby, &file.wire_path))?;
    }
    Ok(paths.as_value())
}

fn ruby_str(ruby: &Ruby, s: &str) -> magnus::Value {
    ruby.str_new(s).as_value()
}

/// `[wire_path, model]` for ONE file, addressed by wire path — the
/// lazy-access path (M2): callers hydrate only the schemas a render
/// touches instead of the whole set.
fn set_hydrate_one(ruby: &Ruby, reader: &SetReader, wire_path: String) -> Result<magnus::Value, Error> {
    let file = reader
        .set
        .files
        .iter()
        .find(|f| f.wire_path == wire_path)
        .ok_or_else(|| {
            Error::new(
                ruby.exception_runtime_error(),
                format!("wire path {wire_path} not in compiled set"),
            )
        })?;
    let wire = file.wire().map_err(|e| {
        Error::new(ruby.exception_runtime_error(), format!("{}: {e}", file.wire_path))
    })?;
    let mut cache = reader.cache.lock().expect("class cache");
    let model = value_to_ruby(ruby, &mut cache, &wire)?;
    let pair = RArray::with_capacity(2);
    pair.push(ruby.str_new(&file.wire_path))?;
    pair.push(model)?;
    Ok(pair.as_value())
}

/// `[wire_path, model]` for the next file in artifact order, nil at
/// the end.
fn set_next(ruby: &Ruby, reader: &SetReader) -> Result<magnus::Value, Error> {
    let mut index = reader.index.lock().expect("index");
    if *index >= reader.set.files.len() {
        return Ok(ruby.qnil().as_value());
    }
    let file = &reader.set.files[*index];
    *index += 1;
    let wire = file.wire().map_err(|e| {
        Error::new(ruby.exception_runtime_error(), format!("{}: {e}", file.wire_path))
    })?;
    let mut cache = reader.cache.lock().expect("class cache");
    let model = value_to_ruby(ruby, &mut cache, &wire)?;
    let pair = RArray::with_capacity(2);
    pair.push(ruby.str_new(&file.wire_path))?;
    pair.push(model)?;
    Ok(pair.as_value())
}

/// Whether the artifact still matches the given {wire_path => read_path}
/// sources; nil when a source is unreadable.
fn set_matches_sources(ruby: &Ruby, reader: &SetReader, read_paths: RHash) -> Result<magnus::Value, Error> {
    let lookup = |wire_path: &str| -> Option<String> {
        read_paths
            .fetch(ruby.str_new(wire_path))
            .ok()
            .and_then(|v| String::try_convert(v).ok())
    };
    match reader.set.matches_sources(&lookup) {
        Some(ok) => Ok(ok.into_value()),
        None => Ok(ruby.qnil().as_value()),
    }
}

/// Write a compiled set from Ruby-provided entries —
/// `[wire_path, source_sha, wire_json]` triples (the post-remark wire
/// of finalized models, so warm loads skip remark attachment).
fn set_write(
    ruby: &Ruby,
    out_path: String,
    entries: RArray,
    expressir_version: String,
) -> Result<magnus::Value, Error> {
    let mut files = Vec::with_capacity(entries.len());
    for index in 0..entries.len() {
        let triple = RArray::from_value(entries.entry(index as isize)?).ok_or_else(|| {
            Error::new(
                ruby.exception_arg_error(),
                "entries must be [wire_path, source_sha, wire_json] triples",
            )
        })?;
        let wire_path: String = triple.entry(0)?;
        let source_sha: String = triple.entry(1)?;
        let wire_json: String = triple.entry(2)?;
        files.push(CompiledFile {
            wire_path,
            source_sha,
            wire_json,
        });
    }
    let set = CompiledSet::build(files, &expressir_version, &expressir_rs::grammar_digest());
    set.write_to(&out_path).map_err(|e| {
        Error::new(
            ruby.exception_io_error(),
            format!("compiled set {out_path}: {e}"),
        )
    })?;
    Ok(ruby.str_new(&set.header.set_digest).as_value())
}

fn value_to_ruby(ruby: &Ruby, cache: &mut ClassCache, wire: &Wire) -> Result<magnus::Value, Error> {
    match wire {
        Wire::Null => Ok(ruby.qnil().as_value()),
        Wire::Bool(b) => Ok(b.into_value()),
        Wire::Number(n) => {
            if let Some(i) = n.as_i64() {
                Ok(ruby.integer_from_i64(i).into_value())
            } else {
                Ok(ruby.float_from_f64(n.as_f64().unwrap_or(0.0)).into_value())
            }
        }
        Wire::String(s) => Ok(ruby.str_new(s).as_value()),
        Wire::Array(items) => {
            let array = ruby.ary_new_capa(items.len());
            for item in items {
                array.push(value_to_ruby(ruby, cache, item)?)?;
            }
            Ok(array.as_value())
        }
        Wire::Object(map) => {
            let class_name = map.get("_class").and_then(Wire::as_str).ok_or_else(|| {
                Error::new(
                    ruby.exception_runtime_error(),
                    "expressir-core: model node without _class",
                )
            })?;
            let klass = cache.resolve(ruby, class_name)?;
            let attrs = RHash::new();
            let mut null_members: Vec<String> = Vec::new();
            for (key, item) in map {
                if matches!(item, Wire::Null) {
                    // instantiate coerces nil collections to []; a null
                    // wire member means the source had no value (e.g. no
                    // parameter parentheses, expressir#558), so it goes
                    // through the setter afterwards, which keeps nil
                    null_members.push(key.clone());
                    continue;
                }
                attrs.aset(ruby.sym_new(key.as_str()), value_to_ruby(ruby, cache, item)?)?;
            }
            let object = klass.funcall::<_, _, magnus::Value>("instantiate", (attrs,))?;
            for key in &null_members {
                // the compiled writers coerce nil collections to [];
                // the raw ivar keeps the null (no parentheses in the
                // source, expressir#558)
                let ivar = format!("@{key}");
                let nil = ruby.qnil().as_value();
                let _: magnus::Value =
                    object.funcall("instance_variable_set", (ivar.as_str(), nil))?;
            }
            Ok(object)
        }
    }
}

fn model_object(ruby: &Ruby, source: String, path: String) -> Result<magnus::Value, Error> {
    let tree = ParsedTree::parse(&source).map_err(|e| {
        Error::new(
            ruby.exception_runtime_error(),
            format!("expressir-core: parse error: {e:?}"),
        )
    })?;
    let wire = tree.to_model_json(&path).map_err(|e| parse_error(ruby, e))?;
    let mut cache = ClassCache::default();
    value_to_ruby(ruby, &mut cache, &wire)
}

#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    let module = ruby.define_module("Expressir")?.define_module("Core")?;
    module.define_singleton_method("parse_to_model_hash", function!(model_json, 2))?;
    module.define_singleton_method("parse_to_model", function!(model_object, 2))?;
    module.define_singleton_method("scan_remarks", function!(scan_remarks, 1))?;
    module.define_singleton_method("write_set", function!(set_write, 3))?;
    let batch_class = module.define_class("BatchStream", ruby.class_object())?;
    batch_class.define_singleton_method("start", function!(batch_start, 2))?;
    batch_class.define_method("next", method!(batch_next, 0))?;
    batch_class.define_method(
        "write_set",
        method!(batch_write_set, 3),
    )?;
    let set_class = module.define_class("Set", ruby.class_object())?;
    set_class.define_singleton_method("open", function!(set_open, 1))?;
    set_class.define_method("digest", method!(set_digest, 0))?;
    set_class.define_method("count", method!(set_count, 0))?;
    set_class.define_method("next", method!(set_next, 0))?;
    set_class.define_method("wire_paths", method!(set_wire_paths, 0))?;
    set_class.define_method("hydrate_one", method!(set_hydrate_one, 1))?;
    set_class.define_method("matches_sources", method!(set_matches_sources, 1))?;
    Ok(())
}
