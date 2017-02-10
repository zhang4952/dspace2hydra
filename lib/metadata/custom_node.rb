module Metadata
  class CustomNode
    include ClassMethodRunner
    attr_reader :config, :field

    def initialize(work_type, config = {})
      @config = config
      @work_type = work_type
    end

    ##
    # Process 'run_method' and add value(s) to data hash
    # @param [Hash] data - the data hash to add processed values to
    # @return [Hash] - the data hash with the new node/values injected
    def process_node(data = {})
      # run_method may return a String, Array<String>, or an Array<Hash>
      result = run_method
      if result.is_a?(String)
        # ensure the form_field is set in the hash and add the processed value to it
        data[field_name] ||= []
        data[field_name] << result
      else
        # run_method returns an array of hashes or strings
        # when the array returns hashes, it expects the shape to be { field_name: '', value: ''}
        # when the array returns strings, add each to the array of the field_name configured for the node
        result.each do |r|
          if r.is_a?(Hash)
            data[form_field(r[:field_name])] ||= []
            data[form_field(r[:field_name])] << r[:value].to_s
          else
            data[field_name] ||= []
            data[field_name] << r.to_s
          end
        end
      end
      data
    end

    ##
    # Given the value from this, run the method configured for the qualifier if it exists otherwise the default
    # @return [String] the result of the configured method should be a string to store in hydra
    def run_method
        raise StandardError.new("#{field} run_method is missing method configuration") unless has_method?
        send(method, @config['value'])
    end

    def method
      @config['method']
    end

    def has_method?
      !method.nil?
    end

    def field_name
      form_field(@config['form_field_name'])
    end

    ##
    # Return the formatted form_field using the provided form_field_name or this nodes qualifiers configured form_field_name
    # Pertinent portion of example configuration:
    # description:
    #   form_field: "generic_work['%{form_field_name}'][]"
    #   qualifiers:
    #     default:
    #       form_field_name: some_field_name
    # @param String form_field_name - a provided string name for the form_field_name
    # @return String - the properly formatted form field name by this nodes configured "form_field" and
    #                   the provided form_field_name or the qualifiers configured "form_field_name"
    def form_field(form_field_name = nil)
      sprintf(@config['form_field'], { work_type: @work_type, form_field_name: form_field_name })
    end
  end
end