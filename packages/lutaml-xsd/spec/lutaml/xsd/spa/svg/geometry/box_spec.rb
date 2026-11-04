# frozen_string_literal: true

require "spec_helper"
require "lutaml/xsd/spa/svg/geometry/box"

RSpec.describe Lutaml::Xsd::Spa::Svg::Geometry::Box do
  let(:box) { described_class.new(10, 20, 100, 50) }

  describe "#initialize" do
    it "creates a box with x, y, width, and height" do
      expect(box.x).to eq(10.0)
      expect(box.y).to eq(20.0)
      expect(box.width).to eq(100.0)
      expect(box.height).to eq(50.0)
    end

    it "converts integer values to float" do
      new_box = described_class.new(5, 10, 50, 25)

      expect(new_box.x).to be_a(Float)
      expect(new_box.width).to be_a(Float)
    end
  end

  describe "#top_left" do
    it "returns the top-left corner point" do
      point = box.top_left

      expect(point.x).to eq(10.0)
      expect(point.y).to eq(20.0)
    end
  end

  describe "#top_right" do
    it "returns the top-right corner point" do
      point = box.top_right

      expect(point.x).to eq(110.0)
      expect(point.y).to eq(20.0)
    end
  end

  describe "#bottom_left" do
    it "returns the bottom-left corner point" do
      point = box.bottom_left

      expect(point.x).to eq(10.0)
      expect(point.y).to eq(70.0)
    end
  end

  describe "#bottom_right" do
    it "returns the bottom-right corner point" do
      point = box.bottom_right

      expect(point.x).to eq(110.0)
      expect(point.y).to eq(70.0)
    end
  end

  describe "#center" do
    it "returns the center point of the box" do
      point = box.center

      expect(point.x).to eq(60.0)
      expect(point.y).to eq(45.0)
    end
  end

  describe "#top_center" do
    it "returns the top-center point" do
      point = box.top_center

      expect(point.x).to eq(60.0)
      expect(point.y).to eq(20.0)
    end
  end

  describe "#bottom_center" do
    it "returns the bottom-center point" do
      point = box.bottom_center

      expect(point.x).to eq(60.0)
      expect(point.y).to eq(70.0)
    end
  end

  describe "#left_center" do
    it "returns the left-center point" do
      point = box.left_center

      expect(point.x).to eq(10.0)
      expect(point.y).to eq(45.0)
    end
  end

  describe "#right_center" do
    it "returns the right-center point" do
      point = box.right_center

      expect(point.x).to eq(110.0)
      expect(point.y).to eq(45.0)
    end
  end

  describe "#contains?" do
    it "returns true when point is inside the box" do
      point = Lutaml::Xsd::Spa::Svg::Geometry::Point.new(50, 40)

      expect(box.contains?(point)).to be true
    end

    it "returns true when point is on the edge" do
      point = Lutaml::Xsd::Spa::Svg::Geometry::Point.new(10, 20)

      expect(box.contains?(point)).to be true
    end

    it "returns false when point is outside the box" do
      point = Lutaml::Xsd::Spa::Svg::Geometry::Point.new(5, 15)

      expect(box.contains?(point)).to be false
    end

    it "returns false when point is beyond right edge" do
      point = Lutaml::Xsd::Spa::Svg::Geometry::Point.new(111, 40)

      expect(box.contains?(point)).to be false
    end

    it "returns false when point is beyond bottom edge" do
      point = Lutaml::Xsd::Spa::Svg::Geometry::Point.new(50, 71)

      expect(box.contains?(point)).to be false
    end
  end
end
