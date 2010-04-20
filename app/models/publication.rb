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

module Publication
  def publication_type_name
    if self.publication_type == 'private'
      if self.owner_is_user?
        _('Owner Only')
      elsif self.owner_is_group?
        _('Members Only')
      else
        ""
      end
    else
      _('Open to All')
    end
  end
  # 全公開かどうか
  def public?
    publication_type == 'public'
  end

  # 自分のみ、参加者のみかどうか
  def private?
    publication_type == 'private'
  end

  # 直接指定かどうか
  def protected?
    publication_type == 'protected'
  end
end
