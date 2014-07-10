require 'aptible/auth'
require 'aptible/api'

module Aptible
  module Rails
    module Controller
      extend ActiveSupport::Concern

      included do
        helper_method :auth, :api, :current_aptible_user,
                      :current_organization, :subscribed?, :has_acccount?,
                      :email_verified?, :subscribed_and_verified?, :user_url,
                      :organization_url
      end

      def auth
        @auth ||= Aptible::Auth::Agent.new(token: service_token).get
      end

      def api
        @api ||= Aptible::Api::Agent.new(token: service_token).get
      end

      def current_aptible_user
        return unless aptible_subject
        @current_user ||= auth.find_by_url(aptible_subject)
      rescue => e
        clear_session_cookie
        raise e
      end

      def current_organization
        session[:organization_url] ||= auth.organizations.first.href
        url = [session[:organization_url], token: service_token]
        @current_organization ||= Aptible::Auth::Organization.find_by_url(*url)
      rescue
        nil
      end

      # rubocop:disable PredicateName
      def has_account?
        current_organization && current_organization.accounts.any?
      end
      # rubocop:enable PredicateName

      def subscribed?
        @has_subscription ||= has_account? &&
        current_organization.accounts.any?(&:has_subscription?)
      end

      def email_verified?
        current_aptible_user && current_aptible_user.verified?
      end

      def subscribed_and_verified?
        has_account? && subscribed? && email_verified?
      end

      def service_token
        return unless aptible_token && aptible_token.session
        @service_token ||= service_token_for(aptible_token)
      end

      def aptible_login_url
        Aptible::Rails.configuration.login_url
      end

      def aptible_subject
        token_subject || session_subject
      end

      def aptible_token
        current_token || session_token
      end

      # before_action :authenticate_user
      def authenticate_aptible_user
        redirect_to aptible_login_url unless current_aptible_user
      end

      # before_action :ensure_service_token
      def ensure_service_token
        redirect_to aptible_login_url unless service_token
      end

      def service_token_for(token)
        service_token = fetch_service_token(token)
        if Fridge::AccessToken.new(service_token).valid?
          service_token
        else
          fetch_service_token(token, force: true) || token
        end
      end

      def fetch_service_token(token, options = {})
        fail 'Token must be a service token' unless token.session
        ::Rails.cache.fetch "service_token:#{token.session}", options do
          swap_session_token(token)
        end
      end

      def swap_session_token(token)
        Aptible::Auth::Token.create(
          client_id: Aptible::Rails.configuration.client_id,
          client_secret: Aptible::Rails.configuration.client_secret,
          subject: token.serialize
        ).access_token
      rescue OAuth2::Error => e
        if e.code == 'unauthorized'
          nil
        else
          fail 'Could not swap session token, check Client#privileged?'
        end
      end

      def organization_url(id)
        "#{dashboard_url}/organizations/#{id}"
      end

      def user_url(id = current_aptible_user.id)
        "#{dashboard_url}/users/#{id}"
      end
    end
  end
end
