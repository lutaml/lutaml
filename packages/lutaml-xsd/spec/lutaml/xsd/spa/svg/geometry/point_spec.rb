# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/spa/svg/geometry/point"

RSpec.describe Lutaml::Xsd::Spa::Svg::Geometry::Point do
  describe "#initialize" do
    it "creates a point with x and y coordinates" do
      point = described_class.new(10, 20)

      expect(point.x).to eq(10.0)
      expect(point.y).to eq(20.0)
    end

    it "converts integer coordinates to float" do
      point = described_class.new(5, 15)

      expect(point.x).to be_a(Float)
      expect(point.y).to be_a(Float)
    end
  end

  describe "#==" do
    it "compares two points for equality" do
      point1 = described_class.new(10, 20)
      point2 = described_class.new(10, 20)
      point3 = described_class.new(15, 25)

      expect(point1).to eq(point2)
      expect(point1).not_to eq(point3)
    end

    it "returns false when comparing with non-Point objects" do
      point = described_class.new(10, 20)

      expect(point).not_to eq([10, 20])
      expect(point).not_to eq("10,20")
    end
  end

  describe "#to_s" do
    it "returns string representation of the point" do
      point = described_class.new(10, 20)

      expect(point.to_s).to eq("(10.0, 20.0)")
    end
  end

  describe "#distance_to" do
    it "calculates distance between two points" do
      point1 = described_class.new(0, 0)
      point2 = described_class.new(3, 4)

      expect(point1.distance_to(point2)).to eq(5.0)
    end

    it "handles negative coordinates" do
      point1 = described_class.new(-3, -4)
      point2 = described_class.new(0, 0)

      expect(point1.distance_to(point2)).to eq(5.0)
    end
  end

  describe "#midpoint_to" do
    it "calculates midpoint between two points" do
      point1 = described_class.new(0, 0)
      point2 = described_class.new(10, 20)

      midpoint = point1.midpoint_to(point2)
      expect(midpoint.x).to eq(5.0)
      expect(midpoint.y).to eq(10.0)
    end

    it "works with negative coordinates" do
      point1 = described_class.new(-10, -20)
      point2 = described_class.new(10, 20)

      midpoint = point1.midpoint_to(point2)
      expect(midpoint.x).to eq(0.0)
      expect(midpoint.y).to eq(0.0)
    end
  end

  describe "#offset" do
    it "creates a new point offset by dx and dy" do
      point = described_class.new(10, 20)
      offset_point = point.offset(5, -3)

      expect(offset_point.x).to eq(15.0)
      expect(offset_point.y).to eq(17.0)
    end

    it "does not modify the original point (immutability)" do
      point = described_class.new(10, 20)
      point.offset(5, -3)

      expect(point.x).to eq(10.0)
      expect(point.y).to eq(20.0)
    end
  end
end
