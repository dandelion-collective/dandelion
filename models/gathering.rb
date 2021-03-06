class Gathering
  include Mongoid::Document
  include Mongoid::Timestamps
  extend Dragonfly::Model

  belongs_to :account, index: true

  field :name, type: String
  field :slug, type: String
  field :location, type: String
  field :coordinates, type: Array
  field :image_uid, type: String
  field :intro_for_members, type: String
  field :welcome_email, type: String
  field :privacy, type: String
  field :intro_for_non_members, type: String
  field :application_questions, type: String
  field :fixed_threshold, type: Integer
  field :member_limit, type: Integer
  field :proposing_delay, type: Integer
  field :processed_via_dandelion, type: Integer
  field :balance, type: Float
  field :paypal_email, type: String
  field :currency, type: String
  field :facebook_group_url, type: String
  field :invitations_granted, type: Integer
  field :stripe_endpoint_secret, type: String
  field :stripe_pk, type: String
  field :stripe_sk, type: String
  field :coinbase_api_key, type: String
  field :coinbase_webhook_secret, type: String
  field :xdai_address, type: String
  field :seeds_username, type: String
  field :redirect_on_acceptance, type: String
  field :choose_and_pay_label, type: String

  def self.enablable
    %w[contributions teams timetables rotas inventory budget partial_payments]
  end
  enablable.each do |x|
    field :"enable_#{x}", type: Boolean
    index({ "enable_#{x}" => 1 })
  end

  %w[enable_comments_on_gathering_homepage enable_supporters clear_up_optionships anonymise_supporters democratic_threshold require_reason_proposer require_reason_supporter demand_payment hide_members_on_application_form hide_invitations ask_for_facebook_profile_url listed].each do |b|
    field b.to_sym, type: Boolean
    index({ b.to_s => 1 })
  end

  def self.admin_fields
    h = {
      name: :text,
      slug: :slug,
      location: :text,
      image: :image,
      intro_for_members: :wysiwyg,
      welcome_email: :wysiwyg,
      fixed_threshold: :number,
      member_limit: :number,
      proposing_delay: :number,
      require_reason_proposer: :check_box,
      require_reason_supporter: :check_box,
      hide_invitations: :check_box,
      processed_via_dandelion: :number,
      stripe_pk: :text,
      stripe_sk: :text,
      stripe_endpoint_secret: :text,
      coinbase_api_key: :text,
      coinbase_webhook_secret: :text,
      balance: :number,
      democratic_threshold: :check_box,
      privacy: :select,
      intro_for_non_members: :wysiwyg,
      application_questions: :text_area,
      enable_supporters: :check_box,
      anonymise_supporters: :check_box,
      clear_up_optionships: :check_box,
      demand_payment: :check_box,
      hide_members_on_application_form: :check_box,
      ask_for_facebook_profile_url: :check_box,
      listed: :check_box,
      paypal_email: :text,
      redirect_on_acceptance: :text,
      currency: :select,
      facebook_group_url: :url,
      account_id: :lookup,
      memberships: :collection,
      mapplications: :collection,
      spends: :collection,
      rotas: :collection,
      teams: :collection
    }
    h.merge(Hash[enablable.map do |x|
                   ["enable_#{x}".to_sym, :check_box]
                 end])
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

  include Geocoder::Model::Mongoid
  geocoded_by :location
  def lat
    coordinates[1] if coordinates
  end

  def lng
    coordinates[0] if coordinates
  end
  after_validation do
    geocode || (self.coordinates = nil) if ENV['GOOGLE_MAPS_API_KEY']
  end

  def self.privacies
    { 'Anyone with the link can join' => 'open', 'People must apply to join' => 'closed', 'Invitation-only' => 'secret' }
  end

  def self.marker_color
    '#00B963'
  end

  def self.marker_icon
    'fa fa-users'
  end

  before_validation do
    errors.add(:fixed_threshold, 'cannot be negative') if fixed_threshold && fixed_threshold.negative?
    errors.add(:member_limit, 'must be positive') if fixed_threshold && !fixed_threshold.positive?
    self.listed = nil if privacy == 'secret'
    self.balance = 0 if balance.nil?
    self.invitations_granted = 0 if invitations_granted.nil?
    self.processed_via_dandelion = 0 if processed_via_dandelion.nil?
    self.enable_teams = true if enable_budget
    self.member_limit = memberships.count if member_limit && (member_limit < memberships.count)
    self.fixed_threshold = nil if democratic_threshold
    true
  end

  def self.admin?(gathering, account)
    account && gathering and ((membership = gathering.memberships.find_by(account: account)) and membership.admin?)
  end

  after_create do
    notifications_as_notifiable.create! circle: circle, type: 'created_gathering'
    memberships.create! account: account, admin: true
    if (dandelion = Organisation.find_by(slug: 'dandelion'))
      dandelion.organisationships.create account: account
    end
    if enable_teams
      general = teams.create! name: 'General', account: account, prevent_notifications: true
      general.teamships.create! account: account, prevent_notifications: true
    end
  end

  def circle
    self
  end

  validates_presence_of :name, :slug, :currency
  validates_uniqueness_of :slug
  validates_format_of :slug, with: /\A[a-z0-9\-]+\z/

  has_many :notifications_as_notifiable, as: :notifiable, dependent: :destroy, class_name: 'Notification', inverse_of: :notifiable
  has_many :notifications_as_circle, as: :circle, dependent: :destroy, class_name: 'Notification', inverse_of: :circle

  has_many :memberships, dependent: :destroy
  has_many :mapplications, dependent: :destroy
  has_many :verdicts, dependent: :destroy
  has_many :payments, dependent: :nullify
  has_many :payment_attempts, dependent: :nullify
  has_many :withdrawals, dependent: :nullify

  # Timetable
  has_many :timetables, dependent: :destroy
  has_many :spaces, dependent: :destroy
  has_many :tslots, dependent: :destroy
  has_many :tactivities, dependent: :destroy
  has_many :attendances, dependent: :destroy
  # Teams
  has_many :teams, dependent: :destroy
  has_many :teamships, dependent: :destroy
  # Rotas
  has_many :rotas, dependent: :destroy
  has_many :roles, dependent: :destroy
  has_many :rslots, dependent: :destroy
  has_many :shifts, dependent: :destroy
  # Options
  has_many :options, dependent: :destroy
  has_many :optionships, dependent: :destroy
  # Budget
  has_many :spends, dependent: :destroy
  # Inventory
  has_many :inventory_items, dependent: :destroy
  # ??Photos
  has_many :photos, as: :photoable, dependent: :destroy

  has_many :posts, as: :commentable, dependent: :destroy
  has_many :subscriptions, as: :commentable, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :comment_reactions, as: :commentable, dependent: :destroy

  def application_questions_a
    q = (application_questions || '').split("\n").map(&:strip).reject { |l| l.blank? }
    q.empty? ? [] : q
  end

  def members
    Account.and(:id.in => memberships.pluck(:account_id))
  end

  def admin_emails
    Account.and(:id.in => memberships.and(admin: true).pluck(:account_id)).pluck(:email)
  end

  def discussers
    Account.and(:id.in => memberships.and(:unsubscribed.ne => true).pluck(:account_id))
  end

  def vouchers
    if enable_supporters
      'proposers + supporters (with at least one proposer)'
    else
      (threshold == 1 ? 'proposer' : 'proposers')
    end
  end

  def incomings
    i = 0
    options.each do |option|
      i += if option.split_cost && option.optionships.count > 0
             option.cost
           else
             option.cost * option.optionships.count
           end
    end
    i
  end

  def anonymise_proposers
    false
  end

  def enable_proposers
    true
  end

  def self.currencies
    CURRENCIES_HASH
  end

  def admins
    Account.and(:id.in => memberships.and(admin: true).pluck(:account_id))
  end

  def self.new_tips
    {
      slug: 'Lowercase letters, numbers and dashes only (no spaces)'
    }
  end

  def self.new_hints
    {
      application_questions: 'Questions to ask applicants. One question per line.',
      currency: 'This cannot be changed, choose wisely',
      fixed_threshold: 'Automatically accept applications with this number of proposers + supporters (with at least one proposer)',
      proposing_delay: 'Accept proposers on applications only once the application is this many hours old',
      stripe_pk: '<code>Developers</code> > <code>API keys</code> > <code>Publishable key</code>. Starts <code>pk_live_</code>',
      stripe_sk: '<code>Developers</code> > <code>API keys</code> > <code>Secret key</code>. Starts <code>sk_live_</code>',
      stripe_endpoint_secret: '<code>Developers</code> > <code>Webhooks</code> > <code>Signing secret</code>. Starts <code>whsec_</code>',
      coinbase_api_key: '<code>Settings</code> > <code>API keys</code>',
      coinbase_webhook_secret: '<code>Settings</code> > <code>Webhook subscriptions</code> > <code>Show shared secret</code>',
      redirect_on_acceptance: 'Experimental',
      enable_teams: 'Create Slack/Facebook-like channels to organise different aspects of the gathering',
      enable_timetables: 'Co-create unconference-style timetables of workshops and activities',
      enable_rotas: 'Allow people to sign up for shifts, for example cooking, washing or community care',
      enable_contributions: 'Allow people to select and pay for core costs, accommodation and transport',
      enable_inventory: 'Allow people to list useful items and take responsibility for bringing them',
      enable_budget: "Show a live and transparent budget of the gathering's finances",
      enable_partial_payments: 'Allow people to pay just a part of any outstanding payment requests',
      demand_payment: 'Require members to make a payment before accessing features like teams or timetables',
      clear_up_optionships: 'Remove people from any unpaid tiers, accommodation and transport options every hour'
    }
  end

  def self.human_attribute_name(attr, options = {})
    {
      ask_for_facebook_profile_url: 'Ask for Facebook profile URL',
      intro_for_non_members: 'Intro for non-members',
      paypal_email: 'PayPal email',
      fixed_threshold: 'Magic number',
      democratic_threshold: 'Allow all gathering members to suggest a magic number, and use the median',
      facebook_group_url: 'Facebook group URL',
      require_reason_proposer: 'Proposers must provide a reason',
      require_reason_supporter: 'Supporters must provide a reason',
      demand_payment: 'Members must make a payment to access gathering content',
      hide_members_on_application_form: "Don't show existing members on the application form",
      invitations_granted: 'People may invite this many others by default',
      hide_invitations: 'Make the number of invitations granted visible to admins only',
      clear_up_optionships: 'Periodically remove people from unpaid options',
      enable_contributions: 'Enable Choose & Pay',
      stripe_endpoint_secret: 'Stripe endpoint secret',
      stripe_pk: 'Stripe public key',
      stripe_sk: 'Stripe secret key',
      coinbase_api_key: 'Coinbase Commerce API key',
      coinbase_webhook_secret: 'Coinbase Commerce webhook secret',
      xdai_address: 'xDai address',
      seeds_username: 'SEEDS username',
      privacy: 'Access',
      listed: 'List this gathering publicly'
    }[attr.to_sym] || super
  end

  def self.edit_tips
    new_tips
  end

  def self.edit_hints
    new_hints
  end

  def threshold
    democratic_threshold ? median_threshold : fixed_threshold
  end

  after_save :create_stripe_webhook_if_necessary, if: :stripe_sk
  def create_stripe_webhook_if_necessary
    Stripe.api_key = stripe_sk

    webhooks = []
    has_more = true
    starting_after = nil
    while has_more
      w = Stripe::WebhookEndpoint.list({ limit: 100, starting_after: starting_after })
      has_more = w['has_more']
      unless w['data'].empty?
        webhooks += w['data']
        starting_after = w['data'].last['id']
      end
    end

    unless webhooks.find { |w| w['url'] == "#{ENV['BASE_URI']}/g/#{slug}/stripe_webhook" && w['enabled_events'].include?('checkout.session.completed') }
      w = Stripe::WebhookEndpoint.create({
                                           url: "#{ENV['BASE_URI']}/g/#{slug}/stripe_webhook",
                                           enabled_events: [
                                             'checkout.session.completed'
                                           ]
                                         })
      update_attribute(:stripe_endpoint_secret, w['secret'])
    end
  end

  def median_threshold
    array = memberships.pluck(:desired_threshold).compact
    if array.length > 0
      sorted = array.sort
      len = sorted.length
      ((sorted[(len - 1) / 2] + sorted[len / 2]) / 2.0).round
    end
  end

  def clear_up_optionships!
    memberships.each do |membership|
      membership.optionships.each do |optionship|
        optionship.destroy if optionship.created_at < 1.hour.ago && optionship.option.cost > membership.paid
      end
    end
  end

  def radio_scopes
    []

    #    if ask_for_date_of_birth
    #      youngest = Account.and(:id.in => memberships.pluck(:account_id)).and(:date_of_birth.ne => nil).order('date_of_birth desc').first
    #      oldest = Account.and(:id.in => memberships.pluck(:account_id)).and(:date_of_birth.ne => nil).order('date_of_birth asc').first
    #      if youngest and oldest
    #        x << [:p, 'all', 'All ages', memberships]
    #        (youngest.age.to_s[0].to_i).upto(oldest.age.to_s[0].to_i) do |p| p = "#{p}0".to_i;
    #          x << [:p, p, "People in their #{p}s", memberships.and(:account_id.in => Account.and(:date_of_birth.lte => (Date.current-p.years)).and(:date_of_birth.gt => (Date.current-(p+10).years)).pluck(:id))]
    #        end
    #      end
    #    end
  end

  def check_box_scopes
    y = []

    y << [:admin, 'Admins', memberships.and(admin: true)]

    y << [:women, 'Women', memberships.and(:account_id.in => members.and(:gender.in => ['Woman', 'Cis Woman']).pluck(:id))]
    y << [:men, 'Men', memberships.and(:account_id.in => members.and(:gender.in => ['Man', 'Cis Man']).pluck(:id))]
    y << [:other_genders, 'Other genders', memberships.and(:account_id.in => members.and(:gender.nin => ['Woman', 'Cis Woman', 'Man', 'Cis Man', nil]).pluck(:id))]
    y << [:unknown_gender, 'Gender not listed', memberships.and(:account_id.in => members.and(gender: nil).pluck(:id))]

    y << [:paid_something, 'Paid something', memberships.and(:paid.gt => 0)]
    y << [:paid_nothing, 'Paid nothing', memberships.and(paid: 0)]
    y << [:more_to_pay, 'More to pay', memberships.and(:id.in => memberships.where('this.paid < this.requested_contribution').pluck(:id))]
    y << [:no_more_to_pay, 'No more to pay', memberships.and(:id.in => memberships.where('this.paid == this.requested_contribution').pluck(:id))]
    y << [:overpaid, 'Overpaid', memberships.and(:id.in => memberships.where('this.paid > this.requested_contribution').pluck(:id))]

    y << [:invitations_granted, 'Custom number of invitations', memberships.and(:invitations_granted.ne => nil)]

    if enable_rotas
      y << [:with_shifts, 'With shifts', memberships.and(:account_id.in => shifts.pluck(:account_id))]
      y << [:without_shifts, 'Without shifts', memberships.and(:account_id.nin => shifts.pluck(:account_id))]
    end

    if enable_teams
      y << [:with_teams, 'With teams', memberships.and(:account_id.in => teamships.and(:team_id.nin => teams.and(name: 'General').pluck(:id)).pluck(:account_id))]
      y << [:without_teams, 'Without teams', memberships.and(:account_id.nin => teamships.and(:team_id.nin => teams.and(name: 'General').pluck(:id)).pluck(:account_id))]
    end

    if enable_contributions
      %w[Tier Accommodation Transport Food].each do |o|
        if optionships.and(:option_id.in => options.and(type: o).pluck(:id)).count > 0
          y << [:"with_#{o.downcase}", "With #{o.downcase}", memberships.and(:account_id.in => optionships.and(:option_id.in => options.and(type: o).pluck(:id)).pluck(:account_id))]
          y << [:"without_#{o.downcase}", "Without #{o.downcase}", memberships.and(:account_id.nin => optionships.and(:option_id.in => options.and(type: o).pluck(:id)).pluck(:account_id))]
        end
      end
    end

    if facebook_group_url
      y << [:member_of_facebook_group, 'Member of Facebook group', memberships.and(member_of_facebook_group: true)]
      y << [:not_member_of_facebook_group, 'Not member of Facebook group', memberships.and(:member_of_facebook_group.ne => true)]
    end

    y << [:threshold, 'Suggesting magic number', memberships.and(:desired_threshold.ne => nil)] if democratic_threshold

    y
  end

  def check_seeds_account
    agent = Mechanize.new
    agent.agent.http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    j = JSON.parse(agent.get("https://telos.caleos.io/v2/history/get_actions?account=#{seeds_username}").body)
    j['actions'].each do |action|
      next unless action['act'] && (data = action['act']['data'])
      next unless data['to'] == seeds_username && data['symbol'] == 'SEEDS' && data['amount'] && !data['memo'].blank? && (seeds_secret = data['memo'].split('SGP: ').last)

      puts "#{data['amount']} SEEDS: #{seeds_secret}"
      Payment.create!(payment_attempt: @payment_attempt) if (@payment_attempt = payment_attempts.find_by(seeds_secret: seeds_secret.downcase, seeds_amount: data['amount']))
    end
  end

  def check_xdai_account
    agent = Mechanize.new
    j = JSON.parse(agent.get("https://blockscout.com/poa/xdai/address/#{xdai_address}/token-transfers?type=JSON").body)
    items = j['items']
    items.each do |item|
      h = Nokogiri::HTML(item)
      to = h.search('[data-test=token_transfer] [data-address-hash]')[1].attr('data-address-hash').downcase
      token = h.search('[data-test=token_link]').text
      next unless to == xdai_address.downcase

      amount = h.search('[data-test=token_transfer] > span')[1].text.split(' ').first.gsub(',', '')

      Payment.create!(payment_attempt: @payment_attempt) if (@payment_attempt = payment_attempts.find_by(currency: token, xdai_amount: amount))
    end
  end
end
