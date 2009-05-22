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

require File.dirname(__FILE__) + '/../../spec_helper'

describe SkipRp::UserSynchronizer, '#sync' do
  before do
    @synchronizer = SkipRp::UserSynchronizer.new 'wiki'
    @service = stub(SkipEmbedded::RpService::Client, :key => 'key', :secret => 'secret')
    @synchronizer.should_receive(:service).and_return(@service)
  end
  it 'SkipRp::Service#sync_usersが実行されること' do
    synchronize_users = [["http://skip/id/boob", "boob", "ボブ", false], ["http://skip/id/alice", "alice", "アリス", true]]
    User.should_receive(:synchronize_users).and_return(synchronize_users)
    @service.should_receive(:sync_users).with(synchronize_users)
    @synchronizer.sync
  end
end

