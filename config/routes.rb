# Copyright © 2011 MUSC Foundation for Research Development
# All rights reserved.

# Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

# 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

# 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following
# disclaimer in the documentation and/or other materials provided with the distribution.

# 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products
# derived from this software without specific prior written permission.

# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING,
# BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT
# SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
# TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

SparcRails::Application.routes.draw do
  match '/direct_link_to/:survey_code', :to => 'surveyor#create', :as => 'direct_link_survey', :via => :get
  mount Surveyor::Engine => "/surveys", :as => "surveyor"

  devise_for :identities, :controllers => { :omniauth_callbacks => "identities/omniauth_callbacks" }

  resources :identities, only: [:show] do
    member do
      post  :show
      get   :approve_account
      get   :disapprove_account
    end

    collection do
      post :add_to_protocol
    end
  end

  resources :reports, only: [:index] do
    member do
      get   :research_project_summary
      post  :cwf_audit
      get   :cwf_subject
    end

    collection do
      get   :setup
      post  :generate
    end
  end

  resources :service_requests, only: [:show] do
    member do
      get   :catalog
      get   :protocol
      get   :review
      get   :obtain_research_pricing
      get   :confirmation
      get   :service_details
      get   :service_calendar
      get   :calendar_totals
      get   :service_subsidy
      get   :document_management
      post  :navigate
      get   :refresh_service_calendar
      get   :save_and_exit
      get   :approve_changes
      post  :add_service
      post  :remove_service
      get   :delete_document
      get   :edit_document
      get   :new_document
    end

    collection do
      post :ask_a_question
      post :feedback
    end

    resources :projects, only: [:new, :create, :edit, :update, :destroy]
    resources :studies, only: [:new, :create, :edit, :update, :destroy]

    resource :service_calendars, only: [:update] do
      member do
        get :table
        get :merged_calendar
      end

      collection do
        put :rename_visit
        put :set_day
        put :set_window_before
        put :set_window_after
        put :update_otf_qty_and_units_per_qty
        put :move_visit_position
        put :show_move_visits
        get :select_calendar_row
        get :unselect_calendar_row
        get :select_calendar_column
        get :unselect_calendar_column
      end
    end
  end

  resources :protocols, only: [:new, :create, :edit, :update, :destroy] do
    member do
      get :approve_epic_rights
      get :push_to_epic
    end
  end

  resources :projects, only: [:new, :create, :edit, :update, :destroy] do
    member do
      get :push_to_epic_status
    end
  end

  resources :studies, only: [:new, :create, :edit, :update, :destroy] do
    member do
      get :push_to_epic_status
    end
  end

  resources :catalogs, only: [] do
    member do
      post :update_description
    end
  end

  resources :search, only: [] do
    collection do
      get :services
      get :identities
    end
  end

  namespace :catalog_manager do # CATALOG MANAGER

    resources :institutions, only:  [:show, :create, :update]
    resources :providers, only:     [:show, :create, :update]
    resources :programs, only:      [:show, :create, :update]
    resources :cores, only:         [:show, :create, :update]

    resources :catalog, only: [:index] do
      collection do
        post    :add_excluded_funding_source
        delete  :remove_excluded_funding_source
        post    :remove_associated_survey
        post    :add_associated_survey
        post    :remove_submission_email
        get     :update_pricing_maps
        get     :update_dates_on_pricing_maps
        get     :validate_pricing_map_dates
        get     :verify_valid_pricing_setups
      end
    end

    resources :services, only: [:show, :new, :create, :update] do
      collection do
        post  :associate
        post  :disassociate
        post  :set_optional
        post  :set_linked_quantity
        post  :set_linked_quantity_total
        get   :verify_parent_service_provider
        get   :get_updated_rate_maps
        post  :update_cores
        get   :search
      end
    end

    resources :identities, only: [] do
      collection do
        post  :associate_with_org_unit
        post  :disassociate_with_org_unit
        post  :set_primary_contact
        post  :set_hold_emails
        post  :set_edit_historic_data
        get   :search
        post  :set_view_draft_status
      end
    end

    root :to => 'catalog#index'
  end

  namespace :portal do # USER PORTAL

    resources :services, only: [:show]

    resources :admin, only: [:index] do
      collection do
        delete :delete_toast_message
      end
    end

    resources :associated_users, only: [:show, :new, :create, :edit, :update, :destroy] do
      collection do
        get :search
      end
    end

    resources :service_requests, only: [:show] do
      member do
        put :update_line_item
        get :refresh_service_calendar
      end
    end

    resources :studies, only: [:index, :show, :new, :create, :edit, :update], controller: :protocols
    resources :projects, only: [:index, :show, :new, :create, :edit, :update], controller: :protocols
    resources :protocols, only: [:index, :show, :new, :create, :edit, :update] do
      member do
        get :add_user
        get :view_full_calendar
      end
      resources :associated_users, only: [:show, :new, :create, :edit, :update, :destroy]
    end

    resources :notifications, only: [:index, :show, :new, :create] do
      member do
        put :user_portal_update
        put :admin_update
      end

      collection do
        put :mark_as_read
      end
    end

    resources :documents, only: [:destroy] do
      member do
        get :download
      end

      collection do
        post :upload
        post :override
      end
    end

    resource :admin, only: [] do # ADMIN PORTAL

      resources :sub_service_requests, only: [:show, :destroy] do
        member do
          put   :update_from_fulfillment
          put   :update_from_project_study_information
          put   :push_to_epic
          put   :add_line_item
          put   :add_otf_line_item
          post  :new_document
          put   :add_note
          get   :edit_documents
          get   :delete_documents
        end
      end

      resources :protocols, only: [:index, :show, :new, :create, :edit, :update] do
        member do
          put   :update_protocol_type
          put   :update_from_fulfillment
          get   :change_arm
          post  :add_arm
          post  :remove_arm
        end
      end

      resources :subsidies, only: [:create, :destroy] do
        member do
          put :update_from_fulfillment
        end
      end

      resources :fulfillments, only: [:create, :destroy] do
        member do
          put :update_from_fulfillment
        end
      end

      resources :line_items, only: [:destroy] do
        member do
          put :update_from_fulfillment
          put :update_from_cwf
        end
      end

      resources :line_items_visits, only: [:destroy] do
        member do
          put :update_from_fulfillment
        end
      end

      resources :visits, only: [:destroy] do
        member do
          put :update_from_fulfillment
        end
      end

      resources :service_requests, only: [:show] do
        member do
          put   :update_from_fulfillment
          post  :add_per_patient_per_visit_visit
          put   :remove_per_patient_per_visit_visit
        end
      end
    end

    root :to => 'home#index'
  end

  match 'rubyception' => 'rubyception/application#index'

  mount API::Base => '/'

  root :to => 'service_requests#catalog'
end
