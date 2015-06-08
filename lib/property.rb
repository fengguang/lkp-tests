LKP_SRC ||= ENV['LKP_SRC']

require "#{LKP_SRC}/lib/common.rb"

class Module
	alias prop_reader attr_reader

	def prop_accessor(*props)
		attr_reader *props
		props.each { |prop|
			class_eval %Q{
def #{prop}_set?
	instance_variable_defined? :"@#{prop}"
end

def set_#{prop}(value)
	@#{prop} = value
	self
end

def unset_#{prop}
	remove_instance_variable :"@#{prop}"
	self
end
			}
		}
	end

	def prop_with(*props)
		prop_accessor *props
		props.each { |prop|
			class_eval %Q{
def with_#{prop}(*values)
	set = #{prop}_set?
	oval = self.#{prop} if set
	values.each { |val|
		set_#{prop} val
		yield val
	}
	self
ensure
	if set
		set_#{prop} oval
	else
		unset_#{prop}
	end
end
			}
		}
	end
end

module Property
	private

	def check_prop_for_set(prop)
		unless respond_to? :"set_#{prop}", true
			raise "Property: '#{prop}' isn't settable!"
		end
	end

	def check_prop_for_unset(prop)
		unless respond_to? :"unset_#{prop}", true
			raise "Property: '#{prop}' isn't unsettable!"
		end
	end

	public

	def get_prop(name)
		send name.intern
	end

	def set_prop(*prop_val_list)
		prop_val_list.each_slice(2) { |prop, val|
			check_prop_for_set prop
		}

		prop_val_list.each_slice(2) { |prop, val|
			send :"set_#{prop}", val
		}
	end

	def unset_props(*props)
		props.each { |prop|
			check_prop_for_unset prop
		}

		props.each { |prop|
			send :"unset_#{prop}"
		}
	end

	def with_prop(prop, *values, &b)
		send :"with_#{prop}", *values, &b
	end
end
