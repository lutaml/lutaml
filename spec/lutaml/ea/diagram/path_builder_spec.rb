# frozen_string_literal: true

require "spec_helper"
require "lutaml/ea/diagram/path_builder"

RSpec.describe Lutaml::Ea::Diagram::PathBuilder do
  let(:connector) { { id: "test", type: "association" } }
  let(:source_element) { { id: "1", x: 100, y: 50, width: 120, height: 80 } }
  let(:target_element) { { id: "2", x: 400, y: 200, width: 150, height: 100 } }
  let(:builder) do
    described_class.new(connector, source_element, target_element)
  end

  describe "#initialize" do
    it "stores connector reference" do
      expect(builder.connector).to eq(connector)
    end

    it "stores source element reference" do
      expect(builder.source_element).to eq(source_element)
    end

    it "stores target element reference" do
      expect(builder.target_element).to eq(target_element)
    end

    it "accepts nil source element" do
      builder_no_source = described_class.new(connector, nil, target_element)
      expect(builder_no_source.source_element).to be_nil
    end

    it "accepts nil target element" do
      builder_no_target = described_class.new(connector, source_element, nil)
      expect(builder_no_target.target_element).to be_nil
    end
  end

  describe "#build_path" do
    context "with EA geometry" do
      it "builds path from EA geometry data" do
        connector[:geometry] = "SX=10;SY=5;EX=-10;EY=-5;EDGE=1;"

        path = builder.build_path

        expect(path).to start_with("M ")
        expect(path).to include(" L ")
        expect(path).not_to eq("M 0,0 L 0,0")
      end

      it "calculates coordinates by manhattan_path with relative offsets" do
        connector[:geometry] = "SX=50;SY=25;EX=0;EY=0;EDGE=1;"

        path = builder.build_path

        # Source point: (100 + 120, 50 + 80/2) = (220, 90)
        # With offsets: (220 + 50, 90 + 25) = (270, 115)
        expect(path).to start_with("M 270,115")
      end

      it "handles negative offsets correctly" do
        connector[:geometry] = "SX=0;SY=0;EX=-30;EY=20;EDGE=1;"

        path = builder.build_path

        # Target point: (400, 200 + 100/2) = (400, 250)
        # With offsets: (400 - 30, 250 + 20) = (370, 270)
        expect(path).to end_with("370,270")
      end

      it "includes waypoints in path when present" do
        connector[:geometry] = "SX=0;SY=0;EX=0;EY=0;EDGE=1;EDGE1=250,125;"

        path = builder.build_path

        # Should have start, waypoint, end
        l_count = path.scan(" L ").count
        expect(l_count).to be >= 2
        expect(path).to include("250,125")
      end

      it "handles multiple waypoints" do
        connector[:geometry] =
          "SX=0;SY=0;EX=0;EY=0;EDGE=1;EDGE1=200,100;" \
          "EDGE2=300,150;EDGE3=400,200;"

        path = builder.build_path

        expect(path).to include("200,100")
        expect(path).to include("300,150")
        expect(path).to include("400,200")
      end
    end

    context "without EA geometry" do
      it "falls back to straight path when coordinates available" do
        connector[:geometry] = nil
        connector[:source_x] = 160
        connector[:source_y] = 90
        connector[:target_x] = 475
        connector[:target_y] = 250

        path = builder.build_path

        expect(path).to eq("M 160,90 L 475,250")
      end

      it "uses manhattan routing by default" do
        connector[:geometry] = nil
        connector[:routing_type] = nil

        path = builder.build_path

        # Manhattan should have multiple segments
        expect(path).to start_with("M ")
        expect(path).to include(" L ")
      end
    end

    context "with orthogonal routing" do
      it "creates right-angle path" do
        connector[:routing_type] = "orthogonal"
        connector[:geometry] = nil

        path = builder.build_path

        # Orthogonal should have multiple line segments
        l_count = path.scan(" L ").count
        expect(l_count).to be >= 2
      end
    end

    context "with bezier routing" do
      it "creates curved path with control points" do
        connector[:routing_type] = "bezier"
        connector[:geometry] = nil

        path = builder.build_path

        expect(path).to include(" C ") # Cubic bezier command
      end
    end

    context "with missing elements" do
      let(:builder_no_elements) { described_class.new(connector, nil, nil) }

      it "handles missing source element gracefully" do
        connector[:geometry] = "SX=10;SY=5;EX=0;EY=0;"

        expect { builder_no_elements.build_path }.not_to raise_error
      end

      it "falls back to default coordinates" do
        path = builder_no_elements.build_path

        expect(path).to be_a(String)
        expect(path).to start_with("M ")
      end
    end
  end

  describe "EA geometry parsing" do
    describe "#parse_ea_geometry" do
      it "parses SX/SY source offsets" do
        connector[:geometry] = "SX=50;SY=25;EX=0;EY=0;EDGE=1;"

        geometry_data = builder.send(:parse_ea_geometry, connector[:geometry])

        expect(geometry_data[:source_offset_x]).to eq(50)
        expect(geometry_data[:source_offset_y]).to eq(25)
      end

      it "parses EX/EY target offsets" do
        connector[:geometry] = "SX=0;SY=0;EX=-30;EY=20;EDGE=1;"

        geometry_data = builder.send(:parse_ea_geometry, connector[:geometry])

        expect(geometry_data[:target_offset_x]).to eq(-30)
        expect(geometry_data[:target_offset_y]).to eq(20)
      end

      it "parses EDGE identifier" do
        connector[:geometry] = "SX=0;SY=0;EX=0;EY=0;EDGE=1;"

        geometry_data = builder.send(:parse_ea_geometry, connector[:geometry])

        expect(geometry_data[:edge]).to eq(1)
      end

      it "parses waypoints from EDGE1, EDGE2, etc." do
        connector[:geometry] =
          "SX=0;SY=0;EX=0;EY=0;EDGE=1;EDGE1=100,50;EDGE2=200,100;"

        geometry_data = builder.send(:parse_ea_geometry, connector[:geometry])

        expect(geometry_data[:waypoints]).to be_an(Array)
        expect(geometry_data[:waypoints].size).to eq(2)
        expect(geometry_data[:waypoints][0]).to eq({ x: 100, y: 50 })
        expect(geometry_data[:waypoints][1]).to eq({ x: 200, y: 100 })
      end

      it "sets has_relative_coords flag when offsets present" do
        connector[:geometry] = "SX=10;SY=0;EX=0;EY=0;"

        geometry_data = builder.send(:parse_ea_geometry, connector[:geometry])

        expect(geometry_data[:has_relative_coords]).to be_truthy
      end

      it "handles missing offsets with nil values" do
        connector[:geometry] = "EDGE=1;"

        geometry_data = builder.send(:parse_ea_geometry, connector[:geometry])

        expect(geometry_data[:source_offset_x]).to be_nil
        expect(geometry_data[:source_offset_y]).to be_nil
      end

      it "returns nil for nil geometry" do
        result = builder.send(:parse_ea_geometry, nil)

        expect(result).to be_nil
      end

      it "returns nil for empty geometry" do
        result = builder.send(:parse_ea_geometry, "")

        expect(result).to be_nil
      end

      it "handles malformed geometry gracefully" do
        geometry_data = builder.send(:parse_ea_geometry, "INVALID;FORMAT;DATA")

        expect(geometry_data).to be_a(Hash)
      end

      it "ignores EA internal variables starting with $" do
        connector[:geometry] = "SX=10;$LLB=ignored;EDGE=1;"

        geometry_data = builder.send(:parse_ea_geometry, connector[:geometry])

        expect(geometry_data.keys).not_to include(:$LLB)
      end

      it "handles geometry with extra whitespace" do
        connector[:geometry] = " SX = 10 ; SY = 5 ; "

        geometry_data = builder.send(:parse_ea_geometry, connector[:geometry])

        expect(geometry_data[:source_offset_x]).to eq(10)
        expect(geometry_data[:source_offset_y]).to eq(5)
      end
    end

    describe "#calculate_start_point" do
      it "calculates absolute start point from source center + offset" do
        geometry_data = { source_offset_x: 20, source_offset_y: 10,
                          has_relative_coords: true }

        start_point = builder.send(:calculate_start_point, geometry_data)

        # Source center: (100 + 120/2, 50 + 80/2) = (160, 90)
        # With offset: (160 + 20, 90 + 10) = (180, 100)
        expect(start_point).to eq([180, 100])
      end

      it "handles zero offsets" do
        geometry_data = { source_offset_x: 0, source_offset_y: 0,
                          has_relative_coords: true }

        start_point = builder.send(:calculate_start_point, geometry_data)

        # Source center: (160, 90)
        expect(start_point).to eq([160, 90])
      end

      it "handles negative offsets" do
        geometry_data = { source_offset_x: -20, source_offset_y: -10,
                          has_relative_coords: true }

        start_point = builder.send(:calculate_start_point, geometry_data)

        # Source center - offset: (160 - 20, 90 - 10) = (140, 80)
        expect(start_point).to eq([140, 80])
      end

      it "returns nil when source element is missing" do
        builder_no_source = described_class.new(connector, nil, target_element)
        geometry_data = { source_offset_x: 10, source_offset_y: 5,
                          has_relative_coords: true }

        result = builder_no_source.send(:calculate_start_point, geometry_data)

        expect(result).to be_nil
      end

      it "returns nil when has_relative_coords is false" do
        geometry_data = { source_offset_x: 10, source_offset_y: 5,
                          has_relative_coords: false }

        result = builder.send(:calculate_start_point, geometry_data)

        expect(result).to be_nil
      end

      it "handles missing offset values as zero" do
        geometry_data = { has_relative_coords: true }

        start_point = builder.send(:calculate_start_point, geometry_data)

        expect(start_point).to eq([160, 90])
      end
    end

    describe "#calculate_end_point" do
      it "calculates absolute end point from target center + offset" do
        geometry_data = { target_offset_x: -15, target_offset_y: 25,
                          has_relative_coords: true }

        end_point = builder.send(:calculate_end_point, geometry_data)

        # Target center: (400 + 150/2, 200 + 100/2) = (475, 250)
        # With offset: (475 - 15, 250 + 25) = (460, 275)
        expect(end_point).to eq([460, 275])
      end

      it "handles zero offsets" do
        geometry_data = { target_offset_x: 0, target_offset_y: 0,
                          has_relative_coords: true }

        end_point = builder.send(:calculate_end_point, geometry_data)

        # Target center: (475, 250)
        expect(end_point).to eq([475, 250])
      end

      it "returns nil when target element is missing" do
        builder_no_target = described_class.new(connector, source_element, nil)
        geometry_data = { target_offset_x: 10, target_offset_y: 5,
                          has_relative_coords: true }

        result = builder_no_target.send(:calculate_end_point, geometry_data)

        expect(result).to be_nil
      end

      it "returns nil when has_relative_coords is false" do
        geometry_data = { target_offset_x: 10, target_offset_y: 5,
                          has_relative_coords: false }

        result = builder.send(:calculate_end_point, geometry_data)

        expect(result).to be_nil
      end
    end
  end

  describe "routing algorithms" do
    describe "#straight_path" do
      it "creates direct line between source and target" do
        connector[:source_x] = 100
        connector[:source_y] = 50
        connector[:target_x] = 400
        connector[:target_y] = 200

        path = builder.send(:straight_path)

        expect(path).to eq("M 100,50 L 400,200")
      end

      it "uses defaults when coordinates missing" do
        path = builder.send(:straight_path)

        expect(path).to eq("M 0,0 L 100,100")
      end
    end

    describe "#manhattan_path" do
      it "creates path with one bend" do
        path = builder.send(:manhattan_path)

        # Should have at least 3 line segments
        l_count = path.scan(" L ").count
        expect(l_count).to be >= 3
      end

      it "chooses horizontal bend for wider spans" do
        # Wider horizontal distance
        wide_source = { id: "1", x: 0, y: 100, width: 100, height: 80 }
        wide_target = { id: "2", x: 500, y: 120, width: 100, height: 80 }
        wide_builder = described_class.new(connector, wide_source, wide_target)

        path = wide_builder.send(:manhattan_path)

        # Path should contain intermediate horizontal points
        expect(path).to match(/M \d+,\d+ L \d+,\d+ L \d+,\d+ L \d+,\d+/)
      end

      it "chooses vertical bend for taller spans" do
        # Taller vertical distance
        tall_source = { id: "1", x: 100, y: 0, width: 100, height: 80 }
        tall_target = { id: "2", x: 120, y: 500, width: 100, height: 80 }
        tall_builder = described_class.new(connector, tall_source, tall_target)

        path = tall_builder.send(:manhattan_path)

        # Path should contain intermediate vertical points
        expect(path).to match(/M \d+,\d+ L \d+,\d+ L \d+,\d+ L \d+,\d+/)
      end
    end

    describe "#bezier_path" do
      it "creates smooth curved path" do
        path = builder.send(:bezier_path)

        expect(path).to start_with("M ")
        expect(path).to include(" C ") # Cubic bezier
        expect(path).not_to include(" L ") # No straight lines
      end

      it "includes control points for curve" do
        path = builder.send(:bezier_path)

        # Format: M x1,y1 C cp1x,cp1y cp2x,cp2y x2,y2
        # Splits into: ["M", "x1,y1", "C", "cp1x,cp1y", "cp2x,cp2y", "x2,y2"]
        parts = path.split
        expect(parts.size).to eq(6)
        expect(parts[0]).to eq("M")
        expect(parts[2]).to eq("C")
      end
    end

    describe "#orthogonal_path" do
      it "creates right-angle routing" do
        path = builder.send(:orthogonal_path)

        # Should have multiple segments
        l_count = path.scan(" L ").count
        expect(l_count).to be >= 2
      end
    end

    describe "#calculate_orthogonal_points" do
      it "generates points for horizontal-first routing" do
        points = builder.send(:calculate_orthogonal_points)

        expect(points).to be_an(Array)
        expect(points.size).to eq(4) # start, 2 intermediate, end
        expect(points[0]).to be_an(Array)
        expect(points[0].size).to eq(2)
      end
    end
  end

  describe "helper methods" do
    describe "#path_from_points" do
      it "converts points array to SVG path string" do
        points = [[100, 50], [200, 100], [300, 150]]

        path = builder.send(:path_from_points, points)

        expect(path).to eq("M 100,50 L 200,100 L 300,150")
      end

      it "returns empty string for empty points array" do
        path = builder.send(:path_from_points, [])

        expect(path).to eq("")
      end

      it "handles single point" do
        points = [[100, 50]]

        path = builder.send(:path_from_points, points)

        expect(path).to eq("M 100,50")
      end
    end

    describe "#source_point" do
      it "uses connector source coordinates when available" do
        connector[:source_x] = 150
        connector[:source_y] = 75

        point = builder.send(:source_point)

        expect(point).to eq([150, 75])
      end

      it "calculates from element when coordinates not in connector" do
        point = builder.send(:source_point)

        # Should calculate connection point from element
        expect(point).to be_an(Array)
        expect(point.size).to eq(2)
      end
    end

    describe "#target_point" do
      it "uses connector target coordinates when available" do
        connector[:target_x] = 450
        connector[:target_y] = 250

        point = builder.send(:target_point)

        expect(point).to eq([450, 250])
      end

      it "calculates from element when coordinates not in connector" do
        point = builder.send(:target_point)

        # Should calculate connection point from element
        expect(point).to be_an(Array)
        expect(point.size).to eq(2)
      end
    end

    describe "#calculate_element_connection_point" do
      it "returns origin for nil element" do
        point = builder.send(:calculate_element_connection_point, nil, :source)

        expect(point).to eq([0, 0])
      end

      it "calculates right-side connection for source" do
        point = builder.send(:calculate_element_connection_point,
                             source_element, :source)

        # Right side: x + width, center height: y + height/2
        expect(point).to eq([220, 90]) # (100 + 120, 50 + 80/2)
      end

      it "calculates left-side connection for target" do
        point = builder.send(:calculate_element_connection_point,
                             target_element, :target)

        # Left side: x, center height: y + height/2
        expect(point).to eq([400, 250]) # (400, 200 + 100/2)
      end

      it "calculates center connection for other types" do
        point = builder.send(:calculate_element_connection_point,
                             source_element, :other)

        # Center: x + width/2, y + height/2
        expect(point).to eq([160, 90]) # (100 + 120/2, 50 + 80/2)
      end

      it "uses default dimensions when missing" do
        element_no_dims = { id: "1", x: 100, y: 50 }

        point = builder.send(:calculate_element_connection_point,
                             element_no_dims, :source)

        # Should use defaults (120, 80)
        expect(point).to eq([220, 90]) # (100 + 120, 50 + 80/2)
      end
    end

    describe "#simple_connector?" do
      it "returns truthy when all coordinates present" do
        connector[:source_x] = 100
        connector[:source_y] = 50
        connector[:target_x] = 400
        connector[:target_y] = 200

        expect(builder.send(:simple_connector?)).to be_truthy
      end

      it "returns falsy when source_x missing" do
        connector[:source_y] = 50
        connector[:target_x] = 400
        connector[:target_y] = 200

        expect(builder.send(:simple_connector?)).to be_falsy
      end

      it "returns falsy when any coordinate missing" do
        connector[:source_x] = 100
        connector[:source_y] = 50
        connector[:target_x] = 400

        expect(builder.send(:simple_connector?)).to be_falsy
      end
    end
  end
end
