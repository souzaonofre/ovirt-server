require 'rexml/document'
require 'qmf'

module Ovirt::SchemaParser
  TYPES = {
    "bool" => Qmf::TYPE_BOOL,
    "objId" => Qmf::TYPE_REF,
    "lstr" => Qmf::TYPE_LSTR,
    "sstr" => Qmf::TYPE_SSTR,
    "uint32" => Qmf::TYPE_UINT32,
    "uint64" => Qmf::TYPE_UINT64
  }

  ACCESS = {
    "RC" => Qmf::ACCESS_READ_CREATE,
    "RW" => Qmf::ACCESS_READ_WRITE,
    "RO" => Qmf::ACCESS_READ_ONLY,
    "R" => Qmf::ACCESS_READ_ONLY
  }

  DIRECTION = {
    "I" => Qmf::DIR_IN,
    "O" => Qmf::DIR_OUT,
    "IO" => Qmf::DIR_IN_OUT
  }

  def schema_parse(xml)
    doc = nil
    File::open(xml, "r") { |fp| doc = REXML::Document.new(fp) }
    package = doc.root.attributes["package"]
    #puts "Package: #{package}"
    klasses = []
    REXML::XPath.each(doc.root, "/schema/class") do |ele|
      klasses << parse_class(package, ele)
    end
    return klasses
  end

  private

  def parse_class(package, ele)
    name = ele.attributes["name"]
    qmf_class = Qmf::SchemaObjectClass.new(package, name)
    #puts "Class: #{name}"
    REXML::XPath.each(ele, "property") do |p|
      qmf_class.add_property(parse_property(p))
    end
    REXML::XPath.each(ele, "method") do |m|
      qmf_class.add_method(parse_method(m))
    end
    return qmf_class
  end

  def parse_property(ele)
    hash = {}
    name = ele.attributes["name"]
    type = typecode(ele.attributes["type"])
    hash = attribute_hash(ele, [:access, :index, :optional, :unit, :desc])
    #puts "  Property: #{name} : #{type.inspect} #{hash.inspect}"
    Qmf::SchemaProperty.new(name, type, hash)
  end

  def parse_method(ele)
    name = ele.attributes["name"]
    hash = attribute_hash(ele, [:desc])
    #puts "  Method: #{name} #{hash.inspect}"
    method = Qmf::SchemaMethod.new(name, hash)
    REXML::XPath.each(ele, "arg") do |a|
      method.add_argument(parse_arg(a))
    end
    method
  end

  def parse_arg(ele)
    name = ele.attributes["name"]
    type = typecode(ele.attributes["type"])
    hash = attribute_hash(ele, [:dir, :unit, :desc])
    #puts "    #{name} : #{type} #{hash.inspect}"
    Qmf::SchemaArgument.new(name, type, hash)
  end

  def attribute_hash(ele, attrs)
    attrs.inject({}) do |hash, kw|
      if v = ele.attributes[kw.to_s]
        # FIXME: Does :unit need conversion ?
        v = access(v) if kw == :access
        v = direction(v) if kw == :dir
        hash[kw] = v
      end
      hash
    end
  end

  def typecode(typename)
    enum_val(TYPES, typename, "type")
  end

  def access(acc)
    enum_val(ACCESS, acc, "access code")
  end

  def direction(dir)
    enum_val(DIRECTION, dir, "direction")
  end

  def enum_val(enum, name, desc)
    unless val = enum[name]
      raise "Unknown #{desc} #{name}"
    end
    return val
  end
end
