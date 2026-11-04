# frozen_string_literal: true

require "spec_helper"

RSpec.describe Expressir::Express::LineMap do
  def map_for(source)
    described_class.new(source.b)
  end

  it "returns 1 for byte position 0" do
    expect(map_for("abc").line_number(0)).to eq(1)
  end

  it "returns 1 for byte positions before the first newline" do
    expect(map_for("abc\ndef").line_number(2)).to eq(1)
  end

  it "returns 2 for the byte position of the first newline + 1" do
    # "abc\ndef": byte 0=a, 1=b, 2=c, 3=\n, 4=d
    expect(map_for("abc\ndef").line_number(4)).to eq(2)
  end

  it "handles CRLF-style sources by counting only \n bytes" do
    # "a\r\nb": bytes a=0, \r=1, \n=2, b=3
    expect(map_for("a\r\nb").line_number(3)).to eq(2)
  end

  it "returns 1 for nil positions (defensive)" do
    expect(map_for("abc").line_number(nil)).to eq(1)
  end

  it "returns 1 for negative positions (defensive)" do
    expect(map_for("abc").line_number(-1)).to eq(1)
  end

  it "returns the last line number for positions past the final newline" do
    expect(map_for("a\nb\nc").line_number(99)).to eq(3)
  end

  it "handles empty source" do
    expect(map_for("").line_number(0)).to eq(1)
  end

  it "answers in O(log n) via binary search on the offset table" do
    source = ("line\n" * 1000)
    map = map_for(source)
    expect(map.line_number(source.bytesize - 1)).to eq(1000)
  end
end
