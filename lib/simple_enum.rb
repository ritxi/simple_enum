# SimpleEnum allows for cross-database, easy to use enum-like fields to be added to your
# ActiveRecord models. It does not rely on database specific column types like <tt>ENUM</tt> (MySQL),
# but instead on integer columns.
#
# Author:: Lukas Westermann
# Copyright:: Copyright (c) 2009 Lukas Westermann (Zurich, Switzerland)
# Licence:: MIT-Licence (http://www.opensource.org/licenses/mit-license.php)
#
# See the +as_enum+ documentation for more details.
module SimpleEnum
  
  # Current simple_enum version string
  VERSION = '0.1.0'
  
  def self.included(base) #:nodoc:
    base.send :extend, ClassMethods
  end
  
  module ClassMethods
    
    # Provides ability to create simple enumerations based on hashes or arrays, backed
    # by integer columns.
    #
    # Columns are supposed to be suffixed by +_cd+, if not, use +:column => 'the_column_name'+,
    # so some example migrations:
    #
    #   add_column :users, :gender_cd, :integer
    #   add_column :users, :status, :integer # and a custom column...
    #      
    # and then in your model:
    #
    #   class User < ActiveRecord::Base
    #     as_enum :gender, [:male, :female]
    #   end
    #
    #   # or use a hash:
    #
    #   class User < ActiveRecord::Base
    #     as_enum :status, { :active => 1, :inactive => 0, :archived => 2, :deleted => 3 }, :column => 'status'
    #   end
    #
    # It automatically creates some useful methods:
    #
    #   @user = User.new
    #   @user.gender          # => nil
    #   @user.gender = :male
    #   @user.gender          # => :male
    #   @user.gender_cd       # => 0
    #   @user.male?           # => true
    #   @user.female?         # => false
    #   @user.female!         # => :female (set's gender to :female => gender_cd = 1)
    #   @user.male?           # => false
    #
    # To access the key/value assocations in a helper like the select helper or similar use:
    #
    #   <%= select(:user, :gender_cd, @user.values_for_gender)
    #
    # Note that the form attribute used is not :gender, but :gender_cd, this is due
    # to the fact that I don't know how to hack into the attributes= method to make
    # that happen :) and I don't think it's a good idea to do so anyway.
    def as_enum(enum_cd, values, options = {})
      options = { :column => "#{enum_cd.to_s}_cd" }.merge(options)
      options.assert_valid_keys(:column, :whiny)
      
      # convert array to hash...
      values = Hash[*values.enum_with_index.to_a.flatten] unless values.respond_to?('invert')
      
      # store info away
      write_inheritable_attribute(:enum_definitions, {}) if enum_definitions.nil?
      enum_definitions[enum_cd] = { :name => enum_cd, :values => values,
                                    :column => options[:column], :options => options }
      enum_definitions[options[:column]] = enum_definitions[enum_cd]
      
      # generate getter       
      define_method(enum_cd.to_s) do
        id = read_attribute options[:column]
        values.invert[id]
      end
      
      # generate setter
      define_method("#{enum_cd.to_s}=") do |new_value|
        write_attribute options[:column], values[new_value.to_sym]
      end
      
      # allow "simple" access to defined values-hash, e.g. in select helper.
      define_method("values_for_#{enum_cd.to_s}") do
        values.clone
      end
      
      # create both, boolean operations and *bang* operations for each
      # enum "value"
      values.each do |k,cd|
        define_method("#{k.to_s}?") do
          cd == read_attribute(options[:column])
        end
        define_method("#{k.to_s}!") do
          write_attribute options[:column], cd
          k
        end
      end
    end
    
    # Validates supplied attributes using the defined enumeration values.
    #
    # TODO: describe options
    def validates_as_enum(*attr_names)
      configuration = { :on => :save }
      configuration.update(attr_names.extract_options!)      
      attr_names.map! { |e| enum_definitions[e][:column] } # map to column name
      
      validates_each(attr_names, configuration) do |record, attr_name, value|
        enum_def = enum_definitions[attr_name]
        unless enum_def[:values].values.include?(value)
          record.errors.add(enum_def[:name], :invalid_enum, :default => configuration[:message], :value => value)
        end
      end
    end
    
    protected
      # Returns enum definitions as defined by each call to
      # +as_enum+.
      def enum_definitions
        read_inheritable_attribute(:enum_definitions)
      end
  end
end

# Tie stuff together and load translations
if Object.const_defined?('ActiveRecord')
  ActiveRecord::Base.send(:include, SimpleEnum)
  I18n.load_path << File.join(File.dirname(__FILE__), '..', 'locales', 'en.yml')  
end