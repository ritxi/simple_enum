require 'active_support/core_ext/string'

module SimpleEnum
  class Enum
    attr_reader :name, :hash

    def initialize(name, hash)
      @name = name.to_s
      @hash = hash
    end

    def include?(key)
      hash.key?(key.to_s) || hash.value?(key)
    end

    def key(value)
      key = hash.key(value)
      key.to_sym if key
    end

    def value(key)
      value = hash[key.to_s]
      value = key if hash.value?(key)
      value
    end
    alias_method :[], :value

    def each_pair(&block)
      hash.each_pair(&block)
    end
    alias_method :each, :each_pair

    def to_s
      name
    end
  end
end
