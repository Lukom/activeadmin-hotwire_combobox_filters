ActiveAdmin::Inputs::Filters::SelectInput.class_eval do
  def select_html # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    return super unless reflection

    current_value = object.public_send(input_name)

    options = []
    if current_value.present?
      current_user = send(ActiveAdmin.application.current_user_method)
      value_record = Pundit.policy_scope!(current_user, reflection.klass).find_by(id: current_value)
      options = HotwireCombobox::Listbox::Item.collection_for(
        template, [value_record], render_in: {}, include_blank: nil, display: :to_combobox_display
      )
    end

    path = template.public_send(:"combobox_search_admin_#{reflection.klass.name.underscore.pluralize}_path")

    builder.combobox(input_name, path, value: current_value, options:)
  end
end
