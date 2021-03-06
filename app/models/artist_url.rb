class ArtistUrl < ApplicationRecord
  before_validation :parse_prefix
  before_validation :initialize_normalized_url, on: :create
  before_validation :normalize
  validates :url, presence: true, uniqueness: { scope: :artist_id }
  validate :validate_url_format
  belongs_to :artist, :touch => true

  def self.strip_prefixes(url)
    url.sub(/^[-]+/, "")
  end

  def self.is_active?(url)
    url !~ /^-/
  end

  def self.normalize(url)
    if url.nil?
      nil
    else
      url = url.gsub(/^https:\/\//, "http://")
      url = url.gsub(/^http:\/\/blog\d+\.fc2/, "http://blog.fc2")
      url = url.gsub(/^http:\/\/blog-imgs-\d+\.fc2/, "http://blog.fc2")
      url = url.gsub(/^http:\/\/blog-imgs-\d+-\w+\.fc2/, "http://blog.fc2")
      url = url.sub(%r!(http://seiga.nicovideo.jp/user/illust/\d+)\?.+!, '\1/')
      url = url.sub(%r!^http://pictures.hentai-foundry.com//!, "http://pictures.hentai-foundry.com/")

      # the strategy won't always work for twitter because it looks for a status
      url = url.downcase if url =~ /https?:\/\/(?:mobile\.)?twitter\.com/

      begin
        url = Sources::Site.new(url).normalize_for_artist_finder!
      rescue Net::OpenTimeout, PixivApiClient::Error
        raise if Rails.env.test?
      rescue Sources::Site::NoStrategyError
      end
      url = url.gsub(/\/+\Z/, "")
      url + "/"
    end
  end

  def self.legacy_normalize(url)
    if url.nil?
      nil
    else
      url = url.gsub(/^https:\/\//, "http://")
      url = url.gsub(/^http:\/\/blog\d+\.fc2/, "http://blog.fc2")
      url = url.gsub(/^http:\/\/blog-imgs-\d+\.fc2/, "http://blog.fc2")
      url = url.gsub(/^http:\/\/blog-imgs-\d+-\w+\.fc2/, "http://blog.fc2")
      url = url.gsub(/^http:\/\/img\d+\.pixiv\.net/, "http://img.pixiv.net")
      url = url.gsub(/^http:\/\/i\d+\.pixiv\.net\/img\d+/, "http://img.pixiv.net")
      url = url.gsub(/\/+\Z/, "")
      url + "/"
    end
  end

  def self.normalize_for_search(url)
    if url =~ /\.\w+\Z/ && url =~ /\w\/\w/
      url = File.dirname(url)
    end

    url = url.gsub(/^https:\/\//, "http://")
    url = url.gsub(/^http:\/\/blog\d+\.fc2/, "http://blog*.fc2")
    url = url.gsub(/^http:\/\/blog-imgs-\d+\.fc2/, "http://blog*.fc2")
    url = url.gsub(/^http:\/\/blog-imgs-\d+-\w+\.fc2/, "http://blog*.fc2")
    url = url.gsub(/^http:\/\/img\d+\.pixiv\.net/, "http://img*.pixiv.net")
    url = url.gsub(/^http:\/\/i\d+\.pixiv\.net\/img\d+/, "http://*.pixiv.net/img*")
  end

  def parse_prefix
    case url
    when /^-/
      self.url = url[1..-1]
      self.is_active = false
    end
  end

  def priority
    if normalized_url =~ /pixiv\.net\/member\.php/
      10

    elsif normalized_url =~ /seiga\.nicovideo\.jp\/user\/illust/
      10

    elsif normalized_url =~ /twitter\.com/ && normalized_url !~ /status/
      15

    elsif normalized_url =~ /tumblr|patreon|deviantart|artstation/
      20

    else
      100
    end
  end

  def normalize
    if !Sources::Site.new(normalized_url).normalized_for_artist_finder?
      self.normalized_url = self.class.normalize(url)
    end
  rescue Sources::Site::NoStrategyError
    self.normalized_url = self.class.normalize(url)
  end

  def initialize_normalized_url
    self.normalized_url = url
  end

  def to_s
    if is_active?
      url
    else
      "-#{url}"
    end
  end

  def validate_url_format
    uri = Addressable::URI.parse(url)
    errors[:url] << "must begin with http:// or https://" if !uri.scheme.in?(%w[http https])
  rescue Addressable::URI::InvalidURIError => error
    errors[:url] << "is malformed: #{error}"
  end
end
