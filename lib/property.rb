LKP_SRC ||= ENV['LKP_SRC']

require "#{LKP_SRC}/lib/common.rb"

class Module
	def check_prop_requirement
		unless include?(Property)
			raise "Must include 'Property' to use prop_xxx method!"
		end
	end

	private :check_prop_requirement

	def prop_accessor(*props)
		check_prop_requirement
		attr_reader *props
		props.each { |prop|
			class_eval %Q{
def set_#{prop}(value)
	@#{prop} = value
	self
end
			}
		}
	end

	def prop_with(*props)
		check_prop_requirement
		prop_accessor *props
		props.each { |prop|
			class_eval %Q{
def with_#{prop}(*vals)
	sym = instance_variable_sym "#{prop}"
	defined = instance_variable_defined? sym
	oval = self.#{prop} if defined
	vals.each { |val|
		set_#{prop} val
		yield val
	}
	self
ensure
	if defined
		set_#{prop} oval
	else
		remove_instance_variable sym
	end
end
			}
		}
	end
end

module Property
	def check_prop_for_set(name)
		unless self.class.method_defined? :"set_\#{name}"
			raise "property: '\#{name}' undefined or unsettable!"
		end
	end

	private :check_prop_for_set

	def set_prop(name, value)
		check_prop_for_set name

		instance_variable_set(instance_variable_sym(name), value)
		self
	end

	def unset_props(*props)
		props.each { |name|
			check_prop_for_set name
		}

		props.each { |name|
			sym = instance_variable_sym(name)
			remove_instance_variable(sym) if instance_variable_defined?(sym)
		}
		self
	end
end
