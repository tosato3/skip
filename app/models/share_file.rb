# SKIP(Social Knowledge & Innovation Platform)
# Copyright (C) 2008-2010 TIS Inc.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.

require 'csv'
class ShareFile < ActiveRecord::Base
  include Publication
  include ::QuotaValidation
  include ::SkipEmbedded::ValidationsFile
  include ::SkipEmbedded::Types::ContentType

  attr_accessor :file

  belongs_to :tenant
  belongs_to :user
  belongs_to :owner, :polymorphic => true
  has_many :tags, :through => :share_file_tags
  has_many :share_file_tags, :dependent => :destroy
  has_many :share_file_accesses, :dependent => :destroy

  validates_length_of   :description, :maximum => 100
  validates_presence_of :file_name
  validates_presence_of :date
  validates_presence_of :user
  validates_presence_of :tenant
  validates_presence_of :owner
  validates_uniqueness_of :file_name, :scope => :owner_id, :message =>_('File with the same name already uploaded.')

  named_scope :owned, proc { |owner|
    { :conditions => ['owner_symbol = ?', owner.symbol] }
  }

  # TODO 回帰テストを書く
  named_scope :accessible, proc { |user|
    if joined_group_ids = Group.active.participating(user).map(&:id) and !joined_group_ids.empty?
      { :conditions => ['share_files.tenant_id = ? AND publication_type = "public" OR owner_id IN (?)', user.tenant_id, joined_group_ids] }
    else
      { :conditions => ['share_files.tenant_id = ? AND publication_type = "public"', user.tenant_id] }
    end
  }

  named_scope :tagged, proc { |tag_words, tag_select|
    return {} unless tag_words
    tag_select = 'AND' unless tag_select == 'OR'
    condition_str = ''
    condition_params = []
    words = tag_words.split(',')
    words.each do |word|
      condition_str << (word == words.last ? ' share_files.category like ?' : " share_files.category like ? #{tag_select}")
      condition_params << SkipUtil.to_like_query_string(word)
    end
    { :conditions => [condition_str, condition_params].flatten }
  }

  def initialize(attr ={})
    super(attr)
    self.publication_type = 'public' if self.publication_type.blank?
  end

  def before_validation_on_create
    if self.file.is_a?(ActionController::UploadedFile)
      self.file_name = file.original_filename
      self.content_type = file.content_type || Types::ContentType::DEFAULT_CONTENT_TYPE
    end
  end

  def validate
    Tag.validate_tags(category).each{ |error| errors.add(:category, error) }
  #  errors.add_to_base _('Operation inexecutable.') unless updatable?
  end

  def validate_on_create
    return unless valid_presence_of_file file

    valid_extension_of_file file
    valid_content_type_of_file file
    valid_size_of_file file
    valid_max_size_of_system_of_file file
  end

  def after_save
    Tag.create_by_comma_tags category, share_file_tags
  end

  def after_create
    self.upload_file
  end

  def after_destroy
    File.delete(self.full_path)
  rescue Errno::ENOENT => e
    logger.error e.message
  rescue => e
    e.backtrace.each { |message| logger.error message }
  end

  # FIXME 後で実装
  def full_accessible? target_user = self.user
    true
  end

  # FIXME 後で実装
  def accessible? target_user = self.user
    true
  end

  # TODO BoardEntryと統合したい
  # 所属するグループの公開範囲により、共有ファイルの公開範囲を判定する
  def owner_is_public?
    !(owner.is_a?(Group) && owner.protected?)
  end

  # TODO ShareFileと統合したい
  def owner_is_user?
    owner.is_a?(User)
  end

  # TODO ShareFileと統合したい
  def owner_is_group?
    owner.is_a?(Group)
  end

#  # TODO owner_symbol_typeのみにしてなくしたい, BoardEntryと統合したい
#  def symbol_type
#    owner_symbol.split(':').first
#  end
#
#  # TODO owner_symbol_idのみにしてなくしたい, BoardEntryと統合したい
#  def symbol_id
#    owner_symbol.split(':')[1]
#  end
#
#  # TODO BoardEntryと統合したい
#  def owner_symbol_type
#    { 'uid' => 'user', 'gid' => 'group' }[symbol_type]
#  end
#
#  # TODO BoardEntryと統合したい
#  def owner_symbol_id
#    owner_symbol.split(':').last
#  end
#
#  # TODO BoardEntryと統合したい
#  def owner_symbol_name
#    owner = Symbol.get_item_by_symbol(self.owner_symbol)
#    owner ? owner.name : ''
#  end
#
#  # TODO BoardEntryと統合したい
#  def owner_id
#    self.class.owner_id owner_symbol
#  end
#
#  # TODO BoardEntryと統合したい
#  def self.owner_id owner_symbol
#    owner(owner_symbol).id
#  end
#
#  # TODO BoardEntryと統合したい
#  def owner
#    self.class.owner owner_symbol
#  end

#  # TODO BoardEntryと統合したい
#  def self.owner owner_symbol
#    symbol_type = owner_symbol.split(":").first
#    symbol_id = owner_symbol.split(":").last
#    owner = (symbol_type == User.symbol_type.to_s) ? User.find_by_uid(symbol_id) : Group.active.find_by_gid(symbol_id)
#  end
#
#
#  # 共有ファイル一覧のタグ用
#  def self.get_tags(owner_symbol)
#    ShareFileTag.find(:all,
#                      :include => [ :share_file, :tag ] ,
#                      :conditions => ["share_files.owner_symbol = ?", owner_symbol]).map{ |tag| tag.tag.name }.uniq
#  end
#
   # FIXME 後で実装
   def categories_hash user
     { :mine => [], :user => [], :popular => [] }
   end

#  def self.get_tags_hash(owner_symbol = nil)
#    # TODO:サブクエリを使うようにしないとアクセス数とデータ数が多くなる
#
#    options = { :conditions => ["owner_symbol = ?", owner_symbol]} if owner_symbol
#    share_files = ShareFile.find(:all, options).map {|share_file| share_file.id}
#
#    owner_tag_names = []
#    popular_tag_names = []
#    if share_files.size > 0
#      options = { :select => 'tags.name',
#                  :joins => 'JOIN tags ON share_file_tags.tag_id = tags.id',
#                  :group => 'share_file_tags.tag_id',
#                  :order => 'count(share_file_tags.tag_id) DESC',
#                  :conditions => ["share_file_tags.share_file_id in (?)", share_files]}
#
#      owner_tag_names = ShareFileTag.find(:all, options).map {|tag| tag.name }
#
#      options[:conditions] = ["share_file_tags.share_file_id not in (?)", share_files]
#      popular_tag_names = owner_symbol ? ShareFileTag.find(:all, options).map {|tag| tag.name } : owner_tag_names # ownerが指定されてないなら同一となる
#
#    end
#    { :mine => owner_tag_names, :user => (popular_tag_names-owner_tag_names).first(10), :popular => popular_tag_names.first(10) }
#  end
#
  # TODO Tagのnamed_scopeにしてなくしたい
  def self.get_popular_tag_words()
    options = { :select => 'tags.name',
                :joins => 'JOIN tags ON share_file_tags.tag_id = tags.id',
                :group => 'share_file_tags.tag_id',
                :order => 'count(share_file_tags.tag_id) DESC'}

    comment_tags = ShareFileTag.find(:all, options)
    tags = []
    comment_tags.each do |tag|
      tags << tag.name
    end
    return tags.uniq.first(40)
  end

#  def visibility
#    text = color = ""
#    if public?
#      text = _("[Open to all]")
#      color = "yellow"
#    elsif private?
#      if owner_symbol.include?("uid")
#        text = _("[Owner only]")
#      else
#        text = _("[Group members only]")
#      end
#      color = "#FFDD75"
#    end
#
#    if text == ""
#      text = "[#{publication_symbols_value}]"
#      color = "#FFCD35"
#    end
#    return text, color
#  end
#
  def create_history login_user_id
    ShareFile.increment_counter("total_count", id)
    ShareFileAccess.create(:share_file_id => id,
                           :user_id => login_user_id)
  end

  def get_accesses_as_csv
    share_file_accesses = ShareFileAccess.find(:all,
                                               :order => "created_at DESC",
                                               :conditions => ["share_file_id = ?", id],
                                               :include => :user)
    buf = ""
    CSV::Writer.generate(buf) do |csv|
      header = [_("Date Accessed"), Admin::Setting.login_account, _('user name')]
      header.map! {|col| NKF.nkf('-sZ', col) }
      csv << header
      share_file_accesses.each do |access|
        csv << [access.created_at.strftime("%Y/%m/%d %H:%M"), access.user.email, NKF.nkf('-sZ', access.user.name)]
      end
    end
    return buf, (file_name.gsub(/\./, '_') + '_history.csv')
  end

  def upload_file src_file = self.file
    open(full_path, "w+b") { |f| f.write(src_file.read) }
  end

  def full_path
    FileUtils.mkdir_p self.dir_path
    File.join(self.dir_path, self.file_name)
  end

  def dir_path
    File.join(SkipEmbedded::InitialSettings['share_file_path'], tenant.id.to_s, owner_type.downcase, owner_id.to_s)
  end
#
#  def self.total_share_file_size symbol
#    sum = 0
#    Dir.glob("#{ShareFile.dir_path(symbol)}/**/*").each do |f|
#      sum += File.stat(f).size
#    end
#    sum
#  end
#
#  def total_share_file_size
#    self.class.total_share_file_size self.owner_symbol
#  end
#
  def file_size
    if File.exist? self.full_path
      File.size self.full_path
    else
      -1
    end
  end

  def file_size_with_unit
    if (size = self.file_size) == -1
      '不明'
    else
      unless (mega_size = size/1.megabyte) == 0
        "#{mega_size}Mbyte"
      else
        unless (kilo_size = size/1.kilobyte) == 0
          "#{kilo_size}Kbyte"
        else
          "#{size}byte"
        end
      end
    end
  end

  def uncheck_authenticity?
    uncheck_extention? && uncheck_content_type?
  end
#
#  def image_extention?
#    CONTENT_TYPE_IMAGES.keys.any?{ |extension| extension.to_s.downcase == extname }
#  end
#
#  def readable?(user = @accessed_user)
#    user ? owner_instance(self, user).readable? : false
#  end
#
#  def updatable?(user = @accessed_user)
#    user ? owner_instance(self, user).updatable? : false
#  end
#
  def extname
    File.extname(file_name).sub(/\A\./,'').downcase
  end

#  class Owner
#    def initialize(share_file, user)
#      @share_file = share_file
#      @user = user
#    end
#
#    def readable?
#      false
#    end
#
#    def updatable?
#      false
#    end
#  end
#
#  class UserOwner < Owner
#    def readable?
#      @user.symbol == @share_file.owner_symbol ? true : publication_range?
#    end
#
#    def publication_range?
#      if @share_file.protected?
#        group_symbols = @user.group_symbols
#        return @share_file.publication_symbols_value.split(',').any?{|symbol| @user.symbol == symbol || group_symbols.include?(symbol) }
#      end
#      @share_file.public?
#    end
#
#    def updatable?
#      @user.symbol == @share_file.owner_symbol
#    end
#  end
#
#  class GroupOwner < Owner
#    def readable?
#      if group = Group.active.find_by_gid(@share_file.owner_symbol_id)
#        participating = @user.participating_group?(group)
#        if participating && (group.administrator?(@user) || @user.id == @share_file.user_id)
#          true
#        else
#          publication_range?(participating)
#        end
#      else
#        false
#      end
#    end
#
#    def publication_range?(participating = true)
#      if @share_file.protected?
#        group_symbols = @user.group_symbols
#        return @share_file.publication_symbols_value.split(',').any?{|symbol| @user.symbol == symbol || group_symbols.include?(symbol) }
#      end
#      @share_file.public? || participating
#    end
#
#    def updatable?
#      if group = Group.active.find_by_gid(@share_file.owner_symbol_id)
#        @user.participating_group?(group) && (group.administrator?(@user) || @user.id == @share_file.user_id)
#      else
#        false
#      end
#    end
#  end

private
  def uncheck_extention?
    uncheck_extentions = CONTENT_TYPE_IMAGES.keys << :swf << :flv
    uncheck_extentions.any?{ |extension| extension.to_s.downcase == extname }
  end

  def uncheck_content_type?
    uncheck_content_types = CONTENT_TYPE_IMAGES.values << 'application/x-shockwave-flash' << 'video/x-flv'
    uncheck_content_types.any?{ |content_types| content_types.split(',').include?(self.content_type) }
  end
#
#  def owner_instance(share_file, user)
#    if owner_is_user?
#      UserOwner.new(share_file, user)
#    elsif owner_is_group?
#      GroupOwner.new(share_file, user)
#    else
#      Owner.new(share_file, user)
#    end
#  end
end
