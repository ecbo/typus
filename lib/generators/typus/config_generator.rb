module Typus
  module Generators
    class ConfigGenerator < Rails::Generators::Base

      source_root File.expand_path("../../templates", __FILE__)

      class_option :admin_title, :default => Rails.root.basename

      desc <<-MSG
Description:
  Creates configuration files and stores them in `config/typus`.

      MSG

      def generate_config
        copy_file "config/typus/README"
        if (@configuration = generate_yaml)[:base].present?
          %w(application.yml application_roles.yml).each do |file|
            template "config/typus/#{file}", "config/typus/#{timestamp}_#{file}"
          end
        end
      end

      protected

      def timestamp
        Time.zone.now.to_s(:number)
      end

      def configuration
        @configuration
      end

      def generate_yaml
        Typus.reload!

        configuration = { :base => "", :roles => "" }

        Typus.application_models.sort { |x,y| x <=> y }.each do |model|

          next if Typus.models.include?(model)

          klass = model.constantize

          relationships = [ :has_many, :has_one ].map do |relationship|
                            klass.reflect_on_all_associations(relationship).map { |i| i.name.to_s }
                          end.flatten

          rejections = %w( ^id$
                           created_at created_on updated_at updated_on deleted_at
                           salt crypted_password
                           password_salt persistence_token single_access_token perishable_token
                           _type$ type
                           _file_size$ )

          default_rejections = (rejections + %w( password password_confirmation )).join("|")
          form_rejections = (rejections + %w( position )).join("|")

          fields = klass.columns.map(&:name)
          default = fields.reject { |f| f.match(default_rejections) }
          form = fields.reject { |f| f.match(form_rejections) }

          # We want attributes of belongs_to relationships to be shown in our
          # field collections if those are not polymorphic.
          [ default, form ].each do |fields|
            fields << klass.reflect_on_all_associations(:belongs_to).reject { |i| i.options[:polymorphic] }.map { |i| i.name.to_s }
            fields.flatten!
          end

          configuration[:base] << <<-RAW
#{klass}:
  fields:
    default: #{default.join(", ")}
    form: #{form.join(", ")}
  relationships: #{relationships.join(", ")}
  application: #{options[:admin_title]}

          RAW

          configuration[:roles] << <<-RAW
  #{klass}: create, read, update, delete
          RAW

        end

        configuration
      end

    end
  end
end
