module Encryptable
  extend ActiveSupport::Concern

  ENCRYPTED_PREFIX = 'encrypted_'.freeze

  class_methods do
    def has_encrypted(attribute, present: false, max_length: nil)
      encrypted_attribute_name = "#{ENCRYPTED_PREFIX}#{attribute}"
      validate_max_length_method_name = "validate_#{attribute}_max_length"

      validate validate_max_length_method_name.to_sym if max_length

      validates_presence_of encrypted_attribute_name if present
      validates_associated encrypted_attribute_name,
        unless: -> { send(encrypted_attribute_name).blank? }

      serialize encrypted_attribute_name, coder: EncryptedMessage

      define_method(validate_max_length_method_name) do
        length = send(encrypted_attribute_name).decoded_ciphertext_length
        if length > max_length
          errors.add(encrypted_attribute_name,
            "is too long. Emojis count more. Length: #{length}, max: #{max_length}")
        end
      end
    end

    def encrypted_attributes
      attribute_names.filter { |name| name.starts_with? ENCRYPTED_PREFIX }
    end
  end
end
