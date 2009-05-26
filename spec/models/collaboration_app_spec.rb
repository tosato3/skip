# SKIP(Social Knowledge & Innovation Platform)
# Copyright (C) 2008-2009 TIS Inc.
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

require File.dirname(__FILE__) + '/../spec_helper'

describe CollaborationApp, '.all_feed_items_by_user' do
  describe 'feed_itemの取得件数が5件の場合' do
    before do
      CollaborationApp.should_receive(:names).and_return(%w[wiki talk])

      collaboration_app_wiki = CollaborationApp.new('wiki')
      collaboration_app_wiki.should_receive(:feed_items_by_user).and_return([
        stub_feed_item(Time.local(2009, 1, 3), '1/3wiki'),
        stub_feed_item(Time.local(2009, 1, 1), '1/1wiki')
      ])
      CollaborationApp.stub!(:new, 'wiki').and_return(collaboration_app_wiki)

      collaboration_app_talk = CollaborationApp.new('talk')
      collaboration_app_talk.should_receive(:feed_items_by_user).and_return([
        stub_feed_item(Time.local(2009, 1, 5), '1/5talk'),
        stub_feed_item(Time.local(2009, 1, 4), '1/4talk'),
        stub_feed_item(Time.local(2009, 1, 2), '1/2talk')
      ])
      CollaborationApp.stub!(:new, 'talk').and_return(collaboration_app_talk)
    end
    it 'feed_itemが5件取得されること' do
      CollaborationApp.all_feed_items_by_user(mock(User)).size.should == 5
    end
    it 'feed_itemが更新日の新しい順番に並んでいること' do
      CollaborationApp.all_feed_items_by_user(mock(User)).map do |item|
        item.title
      end.should == %w(1/5talk 1/4talk 1/3wiki 1/2talk 1/1wiki)
    end
  end
  describe 'feed_itemの取得件数が21件の場合' do
    before do
      CollaborationApp.should_receive(:names).and_return(%w[wiki])
      collaboration_app_wiki = CollaborationApp.new('wiki')
      collaboration_app_wiki.should_receive(:feed_items_by_user).and_return(
        (0..20).map{|i| stub_feed_item(Time.local(2009, 1, i + 1), 'wiki')}
      )
      CollaborationApp.stub!(:new, 'wiki').and_return(collaboration_app_wiki)
    end
    it 'feed_itemが20件取得されること' do
      CollaborationApp.all_feed_items_by_user(mock(User)).size.should == 20
    end
  end

  def stub_feed_item date = Time.now, title = '', link = ''
    stub(Object, :date => date, :title => title, :link => link)
  end
end

describe CollaborationApp, '#feed_items_by_user' do
  describe '対象ユーザのOAuthアクセストークンが登録されていない場合' do
    before do
      UserOauthAccess.should_receive(:find_by_app_name_and_user_id).and_return(nil)
    end
    it '空配列が取得できること' do
      CollaborationApp.new('wiki').feed_items_by_user(mock(User)).should == []
    end
  end
  describe '対象ユーザのOAuthアクセストークンが登録されている場合' do
    before do
      rss_str = <<-RUBY
<?xml version='1.0' encoding='utf-8' ?>
<rss version='2.0' xml:lang='ja' xmlns:content='http://purl.org/rss/1.0/modules/content/' xmlns:dc='http://purl.org/dc/elements/1.1/'>
  <channel>
    <title>あどみんのノート</title>
    <link>/notes</link>
    <description>aioue</description>
    <dc:creator>admin</dc:creator>
    <item>
      <title>[NEW]Vimのーと</title>
      <link>http://localhost:4000/notes/vimnote/pages/FrontPage</link>
      <dc:creator>vimnote</dc:creator>
      <pubDate>Mon, 25 May 2009 16:35:13 +0900</pubDate>
    </item>
  </channel>
</rss>
      RUBY
      @user_oauth_access = stub_model(UserOauthAccess)
      @user_oauth_access.should_receive(:resource).and_return(rss_str)
      UserOauthAccess.should_receive(:find_by_app_name_and_user_id).and_return(@user_oauth_access)
    end
    it 'サイズ1の配列が取得できること' do
      CollaborationApp.new('wiki').feed_items_by_user(mock(User)).size.should == 1
    end
  end
end