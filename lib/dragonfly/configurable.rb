module Dragonfly
  module Configurable

    # Exceptions
    class UnregisteredPlugin < RuntimeError; end

    class Configurer

      class << self
        private
        
        def writer(*args)
          names, opts = extract_options(args)
          names.each do |name|
            define_method name do |value|
              if opts[:for]
                obj.send(opts[:for]).send("#{name}=", value)
              else
                obj.send("#{name}=", value)
              end
            end
          end
        end
        
        def meth(*args)
          names, opts = extract_options(args)
          names.each do |name|
            define_method name do |*args, &block|
              if opts[:for]
                obj.send(opts[:for]).send(name, *args, &block)
              else
                obj.send(name, *args, &block)
              end
            end
          end
        end
        
        def extract_options(args)
          opts = args.last.is_a?(Hash) ? args.pop : {}
          [args, opts]
        end
      end

      def initialize(&block)
        (class << self; self; end).class_eval(&block)
      end

      def configure(obj, &block)
        previous_obj = @obj
        @obj = obj
        instance_eval(&block)
        @obj = previous_obj
      end
      
      def configure_with_plugin(obj, plugin, *args, &block)
        if plugin.is_a?(Symbol)
          raise(UnregisteredPlugin, "plugin #{plugin.inspect} is not registered") unless registered_plugins[plugin]
          plugin = registered_plugins[plugin].call
        end
        plugin.call(obj, *args)
        plugin.instance_eval(&block) if block
        plugin
      end
      
      def register_plugin(name, &block)
        registered_plugins[name] = block
      end
      
      def use(plugin, *args, &block)
        configure_with_plugin(obj, plugin, *args, &block)
      end
      
      private
      
      attr_reader :obj
      
      def registered_plugins
        @registered_plugins ||= {}
      end
    end
    
    #######

    def setup_config(&setup_block)
      self.configurer = Configurer.new(&setup_block)
      class_eval do
        def configure(&block)
          self.class.configurer.configure(self, &block)
          self
        end
        
        def configure_with(plugin, *args, &block)
          self.class.configurer.configure_with_plugin(self, plugin, *args, &block)
          self
        end
      end
    end
    
    attr_accessor :configurer

  end
end
