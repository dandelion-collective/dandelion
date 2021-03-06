class Attachment
  include Mongoid::Document
  include Mongoid::Timestamps
  extend Dragonfly::Model

  belongs_to :organisation, index: true

  field :file_uid, type: String
  field :file_name, type: String
  field :cid, type: String

  def self.admin_fields
    {
      pmail_id: :lookup,
      file: :file,
      file_name: :text,
      cid: :text
    }
  end

  validates_presence_of :file
  dragonfly_accessor :file
end
