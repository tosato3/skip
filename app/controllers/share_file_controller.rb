# SKIP(Social Knowledge & Innovation Platform)
# Copyright (C) 2008 TIS Inc.
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

class ShareFileController < ApplicationController
  layout 'subwindow'

  verify :method => :post, :only => [ :create, :update, :destroy, :download_history_as_csv, :clear_download_history ],
         :redirect_to => { :action => :index }

  def new
    @share_file = ShareFile.new
    @share_file.owner_symbol = params[:owner_symbol]

    params[:publication_type] = "public" if Symbol.split_symbol(@share_file.owner_symbol).first=="uid"
    params[:publication_type] ||= "private"
    params[:publication_symbols_value] = ""

    @error_messages = []
    @owner_name = params[:owner_name]
    @categories_hash = ShareFile.get_tags_hash(@share_file.owner_symbol)
  end

  # post action
  def create
    @error_messages = []
    @share_file = ShareFile.new(params[:share_file])
    @share_file.user_id = session[:user_id]
    @share_file.publication_type = params[:publication_type]
    @share_file.publication_symbols_value = params[:publication_type]=='protected' ? params[:publication_symbols_value] : ""

    # 所有者がマイユーザ OR マイグループ
    unless login_user_symbols.include? @share_file.owner_symbol
      @categories_hash = ShareFile.get_tags_hash(@share_file.owner_symbol)
      redirect_to_with_deny_auth
      return
    end

    unless valid_upload_files? params[:file]
      @categories_hash = ShareFile.get_tags_hash(@share_file.owner_symbol)
      flash.now[:warning] = "ファイルサイズが０、もしくはサイズが大きすぎるファイルがあります。"
      render :action => "new", :layout => "subwindow", :collection => @categories_hash
      return
    end

    params[:file].each do |key,file|
      @share_file = @share_file.clone
      @share_file.file_name = file.original_filename
      @share_file.content_type = file.content_type.chomp

      if not (verify_message = verify_extension_share_file(@share_file)) and
        not (verify_message = verify_file_size(file)) and
        @share_file.save
        target_symbols = analyze_param_publication_type
        target_symbols.each do |target_symbol|
          @share_file.share_file_publications.create(:symbol => target_symbol)
        end
        upload_file file, @share_file.full_path
      else
        error_message = @share_file.file_name

        if @share_file.errors.empty?
          error_message << " ... #{verify_message}"
        else
          error_message << " ... #{@share_file.errors.full_messages.join(",")}"
        end
        @error_messages << error_message
      end
    end

    if @error_messages.size == 0
      render_window_close
    else
      flash.now[:warning] = "ファイルのアップロードに失敗しました。<br/>"
      flash.now[:warning] << "[成功:#{params[:file].size - @error_messages.size} 失敗:#{@error_messages.size}]"

      @reload_parent_window = (params[:file].size - @error_messages.size > 0)
      @share_file.errors.clear
      @owner_name = params[:owner_name]
      @categories_hash = ShareFile.get_tags_hash(@share_file.owner_symbol)
      render :action => "new"
    end
  end

  def edit
    begin
      @share_file = ShareFile.find(params[:id])
    rescue ActiveRecord::RecordNotFound => ex
      render_window_close
      return
    end

    unless authorize_to_save_share_file? @share_file
      render_window_close
      return
    end

    params[:publication_symbols_value] = ""
    if @share_file.public?
      params[:publication_type] = "public"
    elsif @share_file.private?
      params[:publication_type] = "private"
    else
      params[:publication_type] = "protected"
      params[:publication_symbols_value] = @share_file.publication_symbols_value
    end

    @error_messages = []
    @owner_name = params[:owner_name]
    @categories_hash = ShareFile.get_tags_hash(@share_file.owner_symbol)
  end

  # post action
  def update
    @share_file = ShareFile.find(params[:file_id])
    update_params = params[:share_file]
    update_params[:publication_type] = params[:publication_type]
    update_params[:publication_symbols_value] = params[:publication_type]=='protected' ? params[:publication_symbols_value] : ""

    unless authorize_to_save_share_file? @share_file
      @categories_hash = ShareFile.get_tags_hash(@share_file.owner_symbol)
      redirect_to_with_deny_auth
      return
    end

    if @share_file.update_attributes(update_params)
      @share_file.share_file_publications.clear
      target_symbols = analyze_param_publication_type
      target_symbols.each do |target_symbol|
        @share_file.share_file_publications.create(:symbol => target_symbol)
      end

      render_window_close
    else
      @owner_name = params[:owner_name]
      @categories_hash = ShareFile.get_tags_hash(@share_file.owner_symbol)
      render :action => :edit
    end
  end

  # post action
  def destroy
    begin
      share_file = ShareFile.find(params[:id])
    rescue ActiveRecord::RecordNotFound => ex
      redirect_to :controller => 'mypage', :action => 'index'
      return false
    end

    redirect_to_with_deny_auth and return unless authorize_to_save_share_file? share_file

    if share_file.destroy
      flash[:notice] = "ファイルの削除に成功しました。"
    else
      flash[:notice] = "ファイルの削除に失敗しました。"
    end

    redirect_to :controller => share_file.owner_symbol_type, :action => share_file.owner_symbol_id, :id => 'share_file'
  end

  def list
    redirect_to_with_deny_auth and return if not parent_controller

    @owner_name = params[:owner_name]
    @owner_symbol = params[:id]
    @categories = ShareFile.get_tags @owner_symbol
    params[:controller] = parent_controller.params[:controller]
    params[:action] = parent_controller.params[:action]

    params[:sort_type] ||= "date"
    params_hash = { :owner_symbol => @owner_symbol, :category => params[:category],
                    :keyword => params[:keyword], :without_public => params[:without_public] }
    find_params = ShareFile.make_conditions(login_user_symbols, params_hash)
    order_by = (params[:sort_type] == "date" ? "date desc" : "file_name")

    @pages, @share_files = paginate(:share_files,
                                    :conditions => find_params[:conditions],
                                    :include => find_params[:include],
                                    :order => order_by,
                                    :per_page => 10)
    unless @share_files && @share_files.size > 0
      flash.now[:notice] = '該当する共有ファイルはありませんでした。'
    end

    # 編集メニューの表示有無
    @visitor_is_uploader = params[:visitor_is_uploader]
    render :partial => 'share_files', :object => @share_files, :locals => { :pages => @pages }
  end


  def download
    symbol_type_hash = { 'user'  => 'uid',
                         'group' => 'gid' }
    controller_name = params[:controller_name]
    symbol_id = params[:symbol_id]
    file_name =  params[:file_name]
    owner_symbol = "#{symbol_type_hash[controller_name]}:#{symbol_id}"

    # ログインユーザが対象ファイルをダウンロードできるか否か判定
    find_params = ShareFile.make_conditions(login_user_symbols, { :file_name => file_name, :owner_symbol => owner_symbol })
    unless share_file = ShareFile.find(:first, :conditions => find_params[:conditions], :include => find_params[:include] )
      flash[:warning] = '指定されたファイルは存在しません' # 本来は存在する場合でも、ファイルの存在自体を知らせないために、存在しない旨を表示
      redirect_to :controller => 'mypage', :action => 'index'
      return false
    end

    target_file_path = File.join(ENV['SHARE_FILE_PATH'], controller_name, symbol_id, file_name)
    unless File.exist?(target_file_path)
      flash[:warning] = '指定されたファイルの実体が存在しません。お手数ですが管理者にご連絡をお願いいたします。'
      redirect_to :controller => 'mypage', :action => "index"
      return
    end

    share_file.create_history session[:user_id]

    send_file(target_file_path, :filename => nkf_file_name(params[:file_name]), :type => share_file.content_type, :stream => false, :disposition => 'attachment')
  end

  def download_history_as_csv
    unless share_file = ShareFile.find(:first, :conditions => ["id = ?", params[:id]])
      return false
    end

    unless authorize_to_save_share_file? share_file
      send_data(" ", :filename => "dummy.csv", :type => 'application/x-csv', :disposition => 'attachment')
      return
    end

    csv_text, file_name = share_file.get_accesses_as_csv
    send_data(csv_text, :filename => nkf_file_name(file_name), :type => 'application/x-csv', :disposition => 'attachment')
  end

  def clear_download_history
    unless share_file = ShareFile.find(:first, :conditions => ["id = ?", params[:id]])
      return false
    end

    unless authorize_to_save_share_file? share_file
      render :nothing => true
      return
    end

    share_file.share_file_accesses.clear
    render :nothing => true
  end

private

  def upload_file src_file, target_full_path
    open(target_full_path, "w+b") do |f|
      f.write(src_file.read)
    end
  end

  def analyze_param_publication_type
    target_symbols = []
    case params[:publication_type]
    when "public"
      target_symbols << "sid:allusers"
    when "private"
      target_symbols << params[:share_file][:owner_symbol]
      target_symbols << session[:user_symbol]
    when "protected"
      target_symbols = params[:publication_symbols_value].split(/,/).map {|symbol| symbol.strip }
      target_symbols << session[:user_symbol]
    else
      raise "パラメータが不正です"
    end
    target_symbols
  end

  def render_window_close
    render :text => "<script type='text/javascript'>window.opener.location.reload();window.close();</script>"
  end

  def verify_file_size file_obj
    if  file_obj
      if file_obj.size == 0
        return "存在しないもしくはサイズ０のファイルはアップロードできません。"
      elsif file_obj.size > INITIAL_SETTINGS['max_share_file_size'].to_i
        return (INITIAL_SETTINGS['max_share_file_size'].to_i/1024/1024).to_s + "Ｍバイト以上のファイルはアップロードできません。"
      end
    end
    return nil
  end

  def verify_extension_share_file file
      unless verify_extension? file.file_name, file.content_type
        return "この形式のファイルは、アップロードできません。"
      end
      return nil
  end


  def nkf_file_name(file_name)
    agent = request.cgi.env_table["HTTP_USER_AGENT"]
    return  NKF::nkf('-Ws', file_name) if agent.include?("MSIE") and not agent.include?("Opera")
    return file_name
  end

  # 権限チェック
  # ・所有者がマイユーザ
  # ・所有者がマイグループ  AND 作成者がマイユーザ
  def authorize_to_save_share_file? share_file
    session[:user_symbol] == share_file.owner_symbol ||
      (login_user_groups.include?(share_file.owner_symbol) && (session[:user_id] == share_file.user_id))
  end

end
