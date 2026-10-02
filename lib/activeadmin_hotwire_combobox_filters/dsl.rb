module ActiveAdminHotwireComboboxFilters
  module DSL
    DISPLAY_NAME_METHODS = %w[display_name full_name name username login title email to_s].freeze

    def run_registration_block(&block) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      resource_class = config.resource_class

      unless resource_class.public_method_defined?(:to_combobox_display)
        resource_class.class_eval do
          method = DISPLAY_NAME_METHODS.find { |m| public_method_defined?(m) } ||
                   raise(StandardError, "#{resource_class} class lacks to_combobox_display or some display name method")
          alias_method :to_combobox_display, method
        end
      end

      new_block = proc do
        unless controller.action_methods.include?("combobox_search")
          collection_action :combobox_search, method: :get do
            search_fields = params.require(:search_fields)
            scope = active_admin_authorization.scope_collection(resource_class)
            if params[:scope].present? &&
                scope.try(:allowed_combobox_scopes)&.include?(params[:scope]) &&
                scope.respond_to?(params[:scope])
              scope = scope.public_send(params[:scope])
            end

            if params[:selected_ids].present?
              selected_ids = Array(params[:selected_ids]).flat_map { |id| id.to_s.split(",") }.map(&:strip).reject(&:blank?)
              scope = scope.where.not(id: selected_ids) if selected_ids.any?
            end

            scope = scope.ordered if resource_class.respond_to?(:ordered)
            scope = SearchByFields.new(scope:, term: params[:q], fields: search_fields).perform if params[:q].present?
            scope = scope.page(params[:page]).per(Kaminari.config.default_per_page)
            combobox_results = scope.to_a
            next_page = scope.next_page

            render turbo_stream: helpers.async_combobox_options(combobox_results, next_page:)
          end
        end

        unless controller.action_methods.include?("combobox_chips")
          collection_action :combobox_chips, method: %i[get post] do
            raw_values = params[:combobox_values].to_s.split(",")
            scope = active_admin_authorization.scope_collection(resource_class)
            records_by_id = scope.where(id: raw_values).index_by { |r| r.id.to_s }
            fallback_struct = Struct.new(:id, :to_combobox_display)

            items = raw_values.map do |val|
              records_by_id[val] || fallback_struct.new(val, val)
            end

            render turbo_stream: helpers.combobox_selection_chips_for(items)
          end
        end

        instance_exec(&block) if block
      end
      instance_exec(&new_block)
    end
  end
end
