class UserDecorator < ApplicationDecorator
  def can?(scope, account)
    return true if object.can_manage?(account.organization)
    user_scopes = account_permissions(account).map(&:scope)
    user_scopes.include?('manage') || user_scopes.include?(scope)
  end

  def cached_organizations
    garner.bind(h.controller.session_token) do
      object.organizations
    end
  end

  def organization_count
    garner.bind(h.controller.session_token) do
      object.organizations.count
    end
  end

  def cached_roles
    garner.bind(h.controller.session_token) do
      object.roles
    end
  end

  def cached_permissions
    garner.bind(h.controller.session_token) do
      permissions = []
      cached_roles.each do |role|
        permissions += role.permissions
      end
      permissions
    end
  end

  def account_permissions(account)
    cached_permissions.select do |permission|
      permission.links[:account].href == account.href
    end
  end

  def current_training
    training_logs.first
  end

  def training_current?
    training_logs.any?
  end

  def training_logs
    training_criterion.documents.select do |doc|
      doc.links['user'].href == object.href
    end
  end

  def training_criterion
    context[:criterion]
  end
end
