class UserPolicy < ApplicationPolicy
  def show?
    user.present? && record == user
  end
end
