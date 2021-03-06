class Tactivity
  include Mongoid::Document
  include Mongoid::Timestamps
  extend Dragonfly::Model

  belongs_to :timetable, index: true
  belongs_to :account, class_name: 'Account', inverse_of: :tactivities, index: true
  belongs_to :gathering, index: true
  belongs_to :membership, index: true

  belongs_to :space, index: true, optional: true
  belongs_to :tslot, index: true, optional: true
  belongs_to :scheduled_by, class_name: 'Account', inverse_of: :tactivities_scheduled, index: true, optional: true

  field :name, type: String
  field :description, type: String
  field :image_uid, type: String

  def self.admin_fields
    {
      name: :text,
      description: :text_area,
      image: :image,
      account_id: :lookup,
      space_id: :lookup,
      tslot_id: :lookup,
      timetable_id: :lookup,
      gathering_id: :lookup,
      membership_id: :lookup
    }
  end

  has_many :posts, as: :commentable, dependent: :destroy
  has_many :subscriptions, as: :commentable, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :comment_reactions, as: :commentable, dependent: :destroy

  before_validation do
    self.timetable = space.timetable if space
    self.gathering = timetable.gathering if timetable
    self.membership = gathering.memberships.find_by(account: account) if gathering && account && !membership
  end

  dragonfly_accessor :image
  before_validation do
    if image
      begin
        errors.add(:image, 'must be an image') unless %w[jpeg png gif pam].include?(image.format)
      rescue StandardError
        self.image = nil
        errors.add(:image, 'must be an image')
      end
    end
  end

  validates_presence_of :name
  validates_uniqueness_of :space, scope: :tslot, allow_nil: true

  has_many :attendances, dependent: :destroy
  def attendees
    Account.and(:id.in => attendances.pluck(:account_id))
  end

  def discussers
    gathering.discussers.and(:id.in => attendances.pluck(:account_id) + [account.id])
  end

  has_many :notifications, as: :notifiable, dependent: :destroy
  after_create do
    notifications.create! circle: circle, type: 'created_tactivity'
  end

  def circle
    timetable.gathering
  end

  def self.human_attribute_name(attr, options = {})
    {
      name: 'Activity name'
    }[attr.to_sym] || super
  end
end
