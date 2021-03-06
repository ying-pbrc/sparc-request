# coding: utf-8
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

require 'rails_helper'
require 'timecop'

def add_visits_to_arm_line_item(arm, line_item, n=arm.visit_count)
  line_items_visit = LineItemsVisit.for(arm, line_item)

  n.times do |index|
    create(:visit_group, arm_id: arm.id, day: index )
  end

  n.times do |index|
     create(:visit, quantity: 0, line_items_visit_id: line_items_visit.id, visit_group_id: arm.visit_groups[index].id)
  end
end

RSpec.describe ServiceRequestsController do
  stub_controller

  let_there_be_lane
  let_there_be_j
  build_service_request_with_study
  build_one_time_fee_services
  build_per_patient_per_visit_services

  before(:each) do
    add_visits
  end

  let!(:core2) { create(:core, parent_id: program.id) }

  describe 'GET show' do
    it 'should set protocol and service_list' do
      session[:service_request_id] = service_request.id
      get :show, id: service_request.id
      expect(assigns(:protocol)).to eq service_request.protocol
      expect(assigns(:service_list)).to eq service_request.service_list.with_indifferent_access
    end
  end

  describe 'GET catalog' do
    it 'should set institutions to all institutions if there is no sub service request id' do
      session[:service_request_id] = service_request.id
      get :catalog, id: service_request.id
      expect(assigns(:institutions)).to eq Institution.all.sort_by { |i| i.order.to_i }
    end

    it "should set instutitions to the sub service request's institution if there is a sub service request id" do
      session[:service_request_id] = service_request.id
      session[:sub_service_request_id] = sub_service_request.id
      get :catalog, id: service_request.id
      expect(assigns(:institutions)).to eq [ institution ]
    end
  end

  describe 'GET protocol' do
    context 'with study' do
      build_study

      it "should set protocol to the service request's study" do
        session[:identity_id] = jug2.id
        session[:service_request_id] = service_request.id
        session[:sub_service_request_id] = sub_service_request.id
        session[:saved_protocol_id] = study.id
        get :protocol, id: service_request.id
        expect(assigns(:service_request).protocol).to eq study
        expect(session[:saved_protocol_id]).to eq nil
      end

      it "should set studies to the service request's studies if there is a sub service request" do
        # TODO
      end

      it "should set studies to the current user's studies if there is not a sub service request" do
        # TODO
      end

    end

    context 'with project' do
      build_project

      it "should set protocol to the service request's project" do
        session[:identity_id] = jug2.id
        session[:service_request_id] = service_request.id
        session[:sub_service_request_id] = sub_service_request.id
        session[:saved_protocol_id] = project.id
        get :protocol, id: service_request.id
        expect(assigns(:service_request).protocol).to eq project
        expect(session[:saved_protocol_id]).to eq nil
      end

      it "should set projects to the service request's projects if there is a sub service request" do
        # TODO
      end

      it "should set projects to the current user's projects if there is not a sub service request" do
        # TODO
      end
    end
  end

  describe 'GET review' do
    build_project
    build_arms

    it "should set the page if page is passed in" do
      arm1.update_attribute(:visit_count, 200)

      session[:service_request_id] = service_request.id
      get :review, { id: service_request.id, pages: { arm1.id.to_s => 42 } }.with_indifferent_access
      expect(session[:service_calendar_pages]).to eq({arm1.id.to_s => '42'})

      expect(assigns(:pages)).to eq({arm1.id => 1, arm2.id => 1})

      # TODO: check that set_visit_page is called?
    end

    it "should set service_list to the service request's service list" do
      session[:service_request_id] = service_request.id
      get :review, id: service_request.id
      expect(assigns(:service_request).service_list).to eq service_request.service_list
    end

    it "should set protocol to the service request's protocol" do
      session[:service_request_id] = service_request.id
      get :review, id: service_request.id
      expect(assigns(:service_request).protocol).to eq service_request.protocol
    end

    it "should set tab to full calendar" do
      session[:service_request_id] = service_request.id
      get :review, id: service_request.id
      expect(assigns(:tab)).to eq 'calendar'
    end
  end

  describe 'GET confirmation' do
    context 'with project' do
      build_project
      build_arms

      it "should set the service request's status to submitted" do
        session[:identity_id] = jug2.id
        session[:service_request_id] = service_request.id
        get :confirmation, id: service_request.id
        expect(assigns(:service_request).status).to eq 'submitted'
      end

      it "should set the service request's submitted_at to Time.now" do
        session[:identity_id] = jug2.id
        time = Time.parse('2012-06-01 12:34:56')
        Timecop.freeze(time) do
          service_request.update_attribute(:submitted_at, nil)
          session[:service_request_id] = service_request.id
          get :confirmation, id: service_request.id
          service_request.reload
          expect(service_request.submitted_at).to eq Time.now
        end
      end

      it 'should increment next_ssr_id' do
        session[:identity_id] = jug2.id
        service_request.protocol.update_attribute(:next_ssr_id, 42)
        service_request.sub_service_requests.each { |ssr| ssr.destroy }
        ssr = create(
            :sub_service_request,
            service_request_id: service_request.id,
            organization_id: core.id)
        session[:service_request_id] = service_request.id
        get :confirmation, id: service_request.id
        service_request.protocol.reload
        expect(service_request.protocol.next_ssr_id).to eq 43
      end

      it 'should should set status and ssr_id on all the sub service request' do
        session[:identity_id] = jug2.id
        service_request.protocol.update_attribute(:next_ssr_id, 42)
        service_request.sub_service_requests.each { |ssr| ssr.destroy }

        ssr1 = create(
            :sub_service_request,
            service_request_id: service_request.id,
            ssr_id: nil,
            organization_id: provider.id)
        ssr2 = create(
            :sub_service_request,
            service_request_id: service_request.id,
            ssr_id: nil,
            organization_id: core.id)

        session[:service_request_id] = service_request.id
        get :confirmation, id: service_request.id

        ssr1.reload
        ssr2.reload

        expect(ssr1.status).to eq 'submitted'
        expect(ssr2.status).to eq 'submitted'

        expect(ssr1.ssr_id).to eq '0042'
        expect(ssr2.ssr_id).to eq '0043'
      end

      it 'should set ssr_id correctly when next_ssr_id > 9999' do
        session[:identity_id] = jug2.id
        service_request.protocol.update_attribute(:next_ssr_id, 10042)
        service_request.sub_service_requests.each { |ssr| ssr.destroy }

        ssr1 = create(
            :sub_service_request,
            service_request_id: service_request.id,
            ssr_id: nil,
            organization_id: core.id)

        session[:service_request_id] = service_request.id
        get :confirmation, id: service_request.id

        ssr1.reload
        expect(ssr1.ssr_id).to eq '10042'
      end

      it 'should send an email if services are set to send to epic' do
        stub_const("QUEUE_EPIC", false)
        stub_const("USE_EPIC", true)

        session[:identity_id] = jug2.id
        session[:service_request_id] = service_request.id

        service.update_attributes(send_to_epic: false)
        service2.update_attributes(send_to_epic: true)
        protocol = service_request.protocol
        protocol.project_roles.first.update_attribute(:epic_access, true)
        protocol.update_attribute(:selected_for_epic, true)
        deliverer = double()
        expect(deliverer).to receive(:deliver)
        allow(Notifier).to receive(:notify_for_epic_user_approval) { |sr|
          expect(sr).to eq(protocol)
          deliverer
        }

        get :confirmation, {
          id: service_request.id,
          format: :js
        }
      end

      it 'should not send an email if no services are set to send to epic' do
        session[:identity_id] = jug2.id
        session[:service_request_id] = service_request.id

        service.update_attributes(send_to_epic: false)
        service2.update_attributes(send_to_epic: false)

        deliverer = double()
        expect(deliverer).not_to receive(:deliver)
        allow(Notifier).to receive(:notify_for_epic_user_approval) do |sr|
          expect(sr).to eq(service_request)
          deliverer
        end

        get :confirmation, {
          id: service_request.id,
          format: :js
        }
      end
    end
  end

  describe 'GET save_and_exit' do
    context 'with project' do
      build_project
      build_arms

      it "should set the service request's status to submitted" do
        session[:service_request_id] = service_request.id
        get :save_and_exit, id: service_request.id
        expect(assigns(:service_request).status).to eq 'draft'
      end

      it "should NOT set the service request's submitted_at to Time.now" do
        time = Time.parse('2012-06-01 12:34:56')
        Timecop.freeze(time) do
          service_request.update_attribute(:submitted_at, nil)
          session[:service_request_id] = service_request.id
          get :save_and_exit, id: service_request.id
          service_request.reload
          expect(service_request.submitted_at).to eq nil
        end
      end

      it 'should increment next_ssr_id' do
        service_request.protocol.update_attribute(:next_ssr_id, 42)
        service_request.sub_service_requests.each { |ssr| ssr.destroy }
        ssr = create(:sub_service_request, service_request_id: service_request.id, organization_id: core.id)
        session[:service_request_id] = service_request.id
        get :save_and_exit, id: service_request.id
        service_request.protocol.reload
        expect(service_request.protocol.next_ssr_id).to eq 43
      end

      it 'should should set status and ssr_id on all the sub service request' do
        service_request.protocol.update_attribute(:next_ssr_id, 42)

        service_request.sub_service_requests.each { |ssr| ssr.destroy }
        ssr1 = create(:sub_service_request, service_request_id: service_request.id, ssr_id: nil, organization_id: core.id)
        ssr2 = create(:sub_service_request, service_request_id: service_request.id, ssr_id: nil, organization_id: core.id)

        session[:service_request_id] = service_request.id
        get :save_and_exit, id: service_request.id

        ssr1.reload
        ssr2.reload

        expect(ssr1.status).to eq 'draft'
        expect(ssr2.status).to eq 'draft'

        expect(ssr1.ssr_id).to eq '0042'
        expect(ssr2.ssr_id).to eq '0043'
      end

      it 'should set ssr_id correctly when next_ssr_id > 9999' do
        service_request.protocol.update_attribute(:next_ssr_id, 10042)

        service_request.sub_service_requests.each { |ssr| ssr.destroy }
        ssr1 = create(:sub_service_request, service_request_id: service_request.id, ssr_id: nil, organization_id: core.id)

        session[:service_request_id] = service_request.id
        get :save_and_exit, id: service_request.id

        ssr1.reload
        expect(ssr1.ssr_id).to eq '10042'
      end

      it 'should redirect the user to the user portal link' do
        session[:service_request_id] = service_request.id
        get :save_and_exit, id: service_request.id
        expect(response).to redirect_to(USER_PORTAL_LINK)
      end
    end
  end

  describe 'GET service_calendar' do
    build_project
    build_arms

    describe 'GET service_details' do
      it 'should do nothing?' do
        session[:service_request_id] = service_request.id
        get :service_details, id: service_request.id
      end
    end

    let!(:service) {
      service = create(:service, pricing_map_count: 1)
      service.pricing_maps[0].update_attributes(display_date: Date.today)
      service
    }

    let!(:one_time_fee_service) {
      service = create(:service, pricing_map_count: 1, one_time_fee: true)
      service.pricing_maps[0].update_attributes(display_date: Date.today)
      service
    }

    let!(:pricing_map) { service.pricing_maps[0] }
    let!(:one_time_fee_pricing_map) { one_time_fee_service.pricing_maps[0] }

    let!(:line_item) { create(:line_item, service_id: service.id, service_request_id: service_request.id) }
    let!(:one_time_fee_line_item) { create(:line_item, service_id: service.id, service_request_id: service_request.id) }

    it "should set the page if page is passed in" do
      arm1.update_attribute(:visit_count, 500)

      session[:service_request_id] = service_request.id
      get :service_calendar, { id: service_request.id, pages: { arm1.id.to_s => 42 } }.with_indifferent_access
      expect(session[:service_calendar_pages]).to eq({arm1.id.to_s => '42'})
    end

    it 'should set subject count on the per patient per visit line items if it is not set' do
      arm1.update_attribute(:subject_count, 42)

      liv = LineItemsVisit.for(arm1, line_item)
      liv.update_attribute(:subject_count, nil)

      session[:service_request_id] = service_request.id
      get :service_calendar, { id: service_request.id, pages: { arm1.id => 42 } }.with_indifferent_access

      liv.reload
      expect(liv.subject_count).to eq 42
    end

    it 'should set subject count on the per patient per visit line items if it is set and is higher than the visit grouping subject count' do
      arm1.update_attribute(:subject_count, 42)

      liv = LineItemsVisit.for(arm1, line_item)
      liv.update_attribute(:subject_count, 500)

      session[:service_request_id] = service_request.id
      get :service_calendar, { id: service_request.id, pages: { arm1.id => 42 } }.with_indifferent_access

      liv.reload
      expect(liv.subject_count).to eq 42
    end

    it 'should NOT set subject count on the per patient per visit line items if it is set and is lower than the visit grouping subject count' do
      arm1.update_attribute(:subject_count, 42)

      liv = LineItemsVisit.for(arm1, line_item)
      liv.update_attribute(:subject_count, 10)

      session[:service_request_id] = service_request.id
      get :service_calendar, { id: service_request.id, pages: { arm1.id => 42 } }.with_indifferent_access

      liv.reload
      expect(liv.subject_count).to eq 10
    end

    it 'should delete extra visits on per patient per visit line items' do
      arm1.update_attribute(:visit_count, 10)

      liv = LineItemsVisit.for(arm1, line_item)
      liv.visits.each { |visit| visit.destroy }
      add_visits_to_arm_line_item(arm1, line_item, 20)

      session[:service_request_id] = service_request.id
      get :service_calendar, { id: service_request.id, pages: { arm1.id => 42 } }.with_indifferent_access

      liv.reload
      expect(liv.visits.count).to eq 10
    end

    it 'should create visits if too few on per patient per visit line items' do
      arm1.update_attribute(:visit_count, 10)

      liv = LineItemsVisit.for(arm1, line_item)
      add_visits_to_arm_line_item(arm1, line_item, 0)

      session[:service_request_id] = service_request.id
      get :service_calendar, { id: service_request.id, pages: { arm1.id => 42 } }.with_indifferent_access

      liv.reload
      expect(liv.visits.count).to eq 10
    end
  end

  describe 'GET document_management' do
    let!(:service1) { service = create(:service) }
    let!(:service2) { service = create(:service) }

    before(:each) do
      service_list = [ service1, service2 ]

      allow(controller).to receive(:initialize_service_request) do
        controller.instance_eval do
          @service_request = ServiceRequest.find_by_id(session[:service_request_id])
          @sub_service_request = SubServiceRequest.find_by_id(session[:sub_service_request_id])
        end
        allow(controller.instance_variable_get(:@service_request)).to receive(:service_list) { service_list }
      end
    end

    it "should set the service list to the service request's service list" do
      session[:service_request_id] = service_request.id
      get :document_management, id: service_request.id

      expect(assigns(:service_list)).to eq [ service1, service2 ]
    end
  end

  describe 'POST ask_a_question' do
    it 'should call ask_a_question and then deliver' do
      deliverer = double()
      expect(deliverer).to receive(:deliver)
      allow(Notifier).to receive(:ask_a_question) { |quick_question|
        expect(quick_question.to).to eq DEFAULT_MAIL_TO
        expect(quick_question.from).to eq 'no-reply@musc.edu'
        expect(quick_question.body).to eq 'No question asked'
        deliverer
      }
      get :ask_a_question, { quick_question: { email: ''}, quick_question: { body: ''}, id: service_request.id, format: :js }
    end

    it 'should use question_email if passed in' do
      deliverer = double()
      expect(deliverer).to receive(:deliver)
      allow(Notifier).to receive(:ask_a_question) { |quick_question|
        expect(quick_question.from).to eq 'no-reply@musc.edu'
        deliverer
      }
      get :ask_a_question, { id: service_request.id, quick_question: { email: 'no-reply@musc.edu' }, quick_question: { body: '' }, format: :js }
    end

    it 'should use question_body if passed in' do
      deliverer = double()
      expect(deliverer).to receive(:deliver)
      allow(Notifier).to receive(:ask_a_question) { |quick_question|
        expect(quick_question.body).to eq 'is this thing on?'
        deliverer
      }
      get :ask_a_question, { id: service_request.id, quick_question: { email: '' }, quick_question: { body: 'is this thing on?' }, format: :js }
    end
  end

  describe 'GET refresh_service_calendar' do
    build_project
    build_arms

    it "should set the page if page is passed in" do
      arm1.update_attribute(:visit_count, 500)

      session[:service_request_id] = service_request.id
      get :refresh_service_calendar, { id: service_request.id, arm_id: arm1.id, pages: { arm1.id.to_s => 42 }, format: :js }.with_indifferent_access
      expect(session[:service_calendar_pages]).to eq({arm1.id.to_s => 42})

      # TODO: sometimes this is 1 and sometimes it is 42.  I don't know
      # why.
      expect(assigns(:pages)).to eq({arm1.id => 42, arm2.id => 1})

      # TODO: check that set_visit_page is called?
    end

    it 'should set tab to full calendar' do
      session[:service_request_id] = service_request.id
      get :refresh_service_calendar, id: service_request.id, arm_id: arm1.id, format: :js
      expect(assigns(:tab)).to eq 'calendar'
    end
  end

  describe 'POST add_service' do
    let!(:new_service) {
      service = create(
          :service,
          pricing_map_count: 1,
          one_time_fee: true,
          organization_id: core.id)
      service.pricing_maps[0].update_attributes(
          display_date: Date.today,
          quantity_minimum: 42)
      service
    }

    let!(:new_service2) {
      service = create(
          :service,
          pricing_map_count: 1,
          one_time_fee: true,
          organization_id: core.id)
      service.pricing_maps[0].update_attributes(
          display_date: Date.today,
          quantity_minimum: 54)
      service
    }

    let!(:new_service3) {
      service = create(
          :service,
          pricing_map_count: 1,
          organization_id: core2.id)
      service.pricing_maps[0].update_attributes(display_date: Date.today)
      service
    }

    it 'should give an error if the service request already has a line item for the service' do
      line_item = create(
          :line_item,
          service_id: new_service.id,
          service_request_id: service_request.id)
      session[:service_request_id] = service_request.id
      post :add_service, {
        :id          => service_request.id,
        :service_id  => new_service.id,
        :format      => :js
      }.with_indifferent_access
      expect(response.body).to eq 'Service exists in line items'
    end

    it 'should create a line item for the service' do
      orig_count = service_request.line_items.count

      session[:service_request_id] = service_request.id
      post :add_service, {
        :id          => service_request.id,
        :service_id  => new_service.id,
        :format      => :js
      }.with_indifferent_access

      service_request.reload
      expect(service_request.line_items.count).to eq orig_count + 1
      line_item = service_request.line_items.find_by_service_id(new_service.id)
      expect(line_item.service).to eq new_service
      expect(line_item.optional).to eq true
      expect(line_item.quantity).to eq 42
    end

    it 'should create a line item for a required service' do
      orig_count = service_request.line_items.count

      create(
          :service_relation,
          service_id: new_service.id,
          related_service_id: new_service2.id,
          optional: false)

      session[:service_request_id] = service_request.id
      post :add_service, { id: service_request.id, service_id: new_service.id, format: :js }.with_indifferent_access

      # there was one service and one line item already, then we added
      # one

      service_request.reload
      expect(service_request.line_items.count).to eq orig_count + 2
      line_item = service_request.line_items.find_by_service_id(new_service2.id)
      expect(line_item.service).to eq new_service2
      expect(line_item.optional).to eq false
      expect(line_item.quantity).to eq 54
    end

    it 'should create a line item for an optional service' do
      orig_count = service_request.line_items.count

      create(
          :service_relation,
          service_id: new_service.id,
          related_service_id: new_service2.id,
          optional: true)

      session[:service_request_id] = service_request.id
      post :add_service, {
        :id          => service_request.id,
        :service_id  => new_service.id,
        :format      => :js
      }.with_indifferent_access

      service_request.reload
      expect(service_request.line_items.count).to eq orig_count + 2

      line_item = service_request.line_items.find_by_service_id(new_service.id)
      expect(line_item.service).to eq new_service
      expect(line_item.optional).to eq true
      expect(line_item.quantity).to eq 42

      line_item = service_request.line_items.find_by_service_id(new_service2.id)
      expect(line_item.service).to eq new_service2
      expect(line_item.optional).to eq true
      expect(line_item.quantity).to eq 54
    end

    it 'should create a sub service request for each organization in the service list' do
      orig_count = service_request.sub_service_requests.count

      session[:service_request_id] = service_request.id

      [ new_service, new_service2, new_service3 ].each do |service_to_add|
        post :add_service, {
          :id          => service_request.id,
          :service_id  => service_to_add.id,
          :format      => :js
        }.with_indifferent_access
      end

      service_request.reload
      expect(service_request.sub_service_requests.count).to eq orig_count + 2
      expect(service_request.sub_service_requests[-2].organization).to eq core
      expect(service_request.sub_service_requests[-1].organization).to eq core2
    end

    it 'should update each of the line items with the appropriate ssr id' do
      orig_count = service_request.line_items.count

      session[:service_request_id] = service_request.id

      [ new_service, new_service2, new_service3 ].each do |service_to_add|
        post :add_service, {
          :id          => service_request.id,
          :service_id  => service_to_add.id,
          :format      => :js
        }.with_indifferent_access
      end

      core_ssr = service_request.sub_service_requests.find_by_organization_id(core.id)
      core2_ssr = service_request.sub_service_requests.find_by_organization_id(core2.id)

      service_request.reload
      expect(service_request.line_items.count).to eq(orig_count + 3)
      expect(service_request.line_items[-3].sub_service_request).to eq core_ssr
      expect(service_request.line_items[-2].sub_service_request).to eq core_ssr
      expect(service_request.line_items[-1].sub_service_request).to eq core2_ssr
    end

    # TODO: test for adding an already added service
  end

  describe 'POST remove_service' do
    let!(:service1) { service = create( :service, organization_id: core.id) }
    let!(:service2) { service = create( :service, organization_id: core.id) }
    let!(:service3) { service = create( :service, organization_id: core2.id) }

    let!(:line_item1) { create(:line_item, service_id: service1.id, service_request_id: service_request.id) }
    let!(:line_item2) { create(:line_item, service_id: service2.id, service_request_id: service_request.id) }
    let!(:line_item3) { create(:line_item, service_id: service3.id, service_request_id: service_request.id) }

    let!(:ssr1) { create(:sub_service_request, service_request_id: service_request.id, organization_id: core.id) }
    let!(:ssr2) { create(:sub_service_request, service_request_id: service_request.id, organization_id: core2.id) }

    it 'should delete any line items for the removed service' do
      allow(controller.request).to receive(:referrer).and_return('http://example.com')

      line_item1 # create line item (service1, core)
      line_item2 # create line item (service2, core)
      line_item3 # create line item (service3, core2)

      session[:service_request_id] = service_request.id
      post :remove_service, {
        :id            => service_request.id,
        :service_id    => service1.id,
        :line_item_id  => line_item1.id,
        :format        => :js,
      }.with_indifferent_access

      service_request.reload
      expect(service_request.line_items).not_to include(line_item1)
      expect(service_request.line_items).to include(line_item2)
      expect(service_request.line_items).to include(line_item3)
    end

    it 'should delete sub service requests for organizations that no longer have a service in the service request' do
      allow(controller.request).to receive(:referrer).and_return('http://example.com')

      line_item1 # create line item (service1, core)
      line_item2 # create line item (service2, core)
      line_item3 # create line item (service3, core2)

      ssr1 # create ssr (core)
      ssr2 # create ssr (core2)

      session[:service_request_id] = service_request.id

      post :remove_service, {
        :id            => service_request.id,
        :service_id    => service1.id,
        :line_item_id  => line_item1.id,
        :format        => :js,
      }.with_indifferent_access

      service_request.reload
      expect(service_request.sub_service_requests).to include(ssr1)
      expect(service_request.sub_service_requests).to include(ssr2)

      post :remove_service, {
        :id            => service_request.id,
        :service_id    => service2.id,
        :line_item_id  => line_item2.id,
        :format        => :js,
      }.with_indifferent_access

      service_request.reload
      expect(service_request.sub_service_requests).not_to include(ssr1)
      expect(service_request.sub_service_requests).to include(ssr2)

      post :remove_service, {
        :id            => service_request.id,
        :service_id    => service3.id,
        :line_item_id  => line_item3.id,
        :format        => :js,
      }.with_indifferent_access

      service_request.reload
      expect(service_request.sub_service_requests).not_to include(ssr1)
      expect(service_request.sub_service_requests).not_to include(ssr2)
    end

    it 'should set the page' do
      allow(controller.request).to receive(:referrer).and_return('http://example.com/foo/bar')

      line_item1 # create line item (service1, core)
      line_item2 # create line item (service2, core)
      line_item3 # create line item (service3, core2)

      session[:service_request_id] = service_request.id
      post :remove_service, {
        :id            => service_request.id,
        :service_id    => service1.id,
        :line_item_id  => line_item1.id,
        :format        => :js,
      }.with_indifferent_access

      # TODO: why is @page set to a string in this method but set to an
      # integer elsewhere?
      expect(assigns(:page)).to eq 'bar'
    end

    it 'should raise an exception if a service is removed twice' do
      allow(controller.request).to receive(:referrer).and_return('http://example.com')

      line_item1 # create line item (service1, core)
      line_item2 # create line item (service2, core)
      line_item3 # create line item (service3, core2)

      session[:service_request_id] = service_request.id

      post :remove_service, {
        :id            => service_request.id,
        :service_id    => service1.id,
        :line_item_id  => line_item1.id,
        :format        => :js,
      }.with_indifferent_access

      expect {
        post :remove_service, {
          :id            => service_request.id,
          :service_id    => service1.id,
          :line_item_id  => line_item1.id,
          :format        => :js,
        }.with_indifferent_access
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'POST delete_documents' do
    let!(:doc)  { Document.create(service_request_id: service_request.id) }
    let!(:ssr1) { create(:sub_service_request, service_request_id: service_request.id, organization_id: core.id)  }
    let!(:ssr2) { create(:sub_service_request, service_request_id: service_request.id, organization_id: core2.id) }

    context('document methods') do

      before(:each) do
        doc.sub_service_requests << ssr1
        doc.sub_service_requests << ssr2
      end

      it 'should set tr_id' do
        session[:service_request_id] = service_request.id
        post :delete_documents, {
          :id                => service_request.id,
          :document_id       => doc.id,
          :format            => :js,
        }.with_indifferent_access
        expect(assigns(:tr_id)).to eq "#document_id_#{doc.id}"
      end

      it 'should destroy the document if there is no sub service request' do
        session[:service_request_id] = service_request.id
        post :delete_documents, {
          :id                => service_request.id,
          :document_id       => doc.id,
          :format            => :js,
        }.with_indifferent_access

        expect {
          doc.reload
        }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it 'should destroy only the document for that sub service request if there is a sub service request' do
        session[:service_request_id] = service_request.id
        session[:sub_service_request_id] = ssr1.id
        post :delete_documents, {
          :id                      => service_request.id,
          :document_id             => doc.id,
          :format                  => :js,
        }.with_indifferent_access

        doc.reload
        expect(doc.destroyed?).to eq false
        expect(doc.sub_service_requests.size).to eq 1
      end
    end
  end

  describe 'POST edit_documents' do
    let!(:doc)  { Document.create(service_request_id: service_request.id) }
    let!(:ssr1) { create(:sub_service_request, service_request_id: service_request.id, organization_id: core.id)  }
    let!(:ssr2) { create(:sub_service_request, service_request_id: service_request.id, organization_id: core2.id) }

    context('document methods') do

      before(:each) do
        doc.sub_service_requests << ssr1
        doc.sub_service_requests << ssr2
      end

      it 'should set document' do
        session[:service_request_id] = service_request.id
        post :edit_documents, {
          :id                      => service_request.id,
          :document_id             => doc.id,
          :format                  => :js,
        }.with_indifferent_access
        expect(assigns(:document)).to eq doc
      end

      it 'should set service_list' do
        session[:service_request_id] = service_request.id
        post :edit_documents, {
          :id                      => service_request.id,
          :document_id             => doc.id,
          :format                  => :js,
        }.with_indifferent_access
        expect(assigns(:service_list)).to eq service_request.service_list.with_indifferent_access
      end
    end
  end

  describe 'POST new_document' do
    let!(:doc)  { Document.create(service_request_id: service_request.id) }
    let!(:ssr1) { create(:sub_service_request, service_request_id: service_request.id, organization_id: core.id)  }
    let!(:ssr2) { create(:sub_service_request, service_request_id: service_request.id, organization_id: core2.id) }

    context('document methods') do

      before(:each) do
        doc.sub_service_requests << ssr1
        doc.sub_service_requests << ssr2
      end

      it 'should set service_list' do
        session[:service_request_id] = service_request.id
        post :edit_documents, {
          :id                      => service_request.id,
          :document_id             => doc.id,
          :format                  => :js,
        }.with_indifferent_access
        expect(assigns(:service_list)).to eq service_request.service_list.with_indifferent_access
      end
    end
  end

  describe 'POST document_management navigate' do
    let!(:doc)  { Document.create(service_request_id: service_request.id) }
    let!(:ssr1) { create(:sub_service_request, service_request_id: service_request.id, organization_id: core.id)  }
    let!(:ssr2) { create(:sub_service_request, service_request_id: service_request.id, organization_id: core2.id) }

    before(:each) do
      @request.env['HTTP_REFERER'] = "/service_requests/#{service_request.id}/document_management"
      controller.instance_variable_set(:@validation_groups, {review_view: ['document_management']})
      session[:service_request_id] = service_request.id
      doc.sub_service_requests << ssr1
      doc.sub_service_requests << ssr2
    end

    it 'should create a new document' do
      expect(service_request.documents.size).to eq(1)
      post :navigate, {
        :location                     => 'document_management',
        :current_location             => 'document_management',
        process_ssr_organization_ids: [ssr1.organization_id.to_s, ssr2.organization_id.to_s],
        :doc_type                     => 'budget',
        :upload_clicked               => '1',
        :document                     => file_for_upload,
        :action                       => 'document_management',
        :controller                   => 'service_requests',
        :id                           => service_request.id
      }.with_indifferent_access
      expect(service_request.documents.size).to eq(2)
    end

    it 'should update an existing document' do
      expect(doc.sub_service_requests.size).to eq(2)
      post :navigate, {
        :location                     => 'document_management',
        :current_location             => 'document_management',
        :document_id                  => doc.id.to_s,
        process_ssr_organization_ids: [ssr2.organization_id.to_s],
        :doc_type                     => 'budget',
        :upload_clicked               => '1',
        :action                       => 'document_management',
        :controller                   => 'service_requests',
        :id                           => service_request.id
      }.with_indifferent_access
      # access removed from ssr1 to document and doc_type changed to budget
      doc.reload
      expect(doc.sub_service_requests).to eq([ssr2])
      expect(doc.doc_type).to eq('budget')
    end
  end

  describe 'GET service_subsidy' do
    it 'should set subsidies to an empty array if there are no sub service requests' do
      service_request.sub_service_requests.each { |ssr| ssr.destroy }
      service_request.reload
      session[:service_request_id] = service_request.id
      get :service_subsidy, id: service_request.id
      expect(assigns(:subsidies)).to eq [ ]
    end

    it 'should put the subsidy into subsidies if the ssr has a subsidy' do
      session[:service_request_id] = service_request.id
      get :service_subsidy, id: service_request.id
      expect(assigns(:subsidies)).to eq [ subsidy ]
    end

    it 'should create a new subsidy and put it into subsidies if the ssr does not have a subsidy and it is eligible for subsidy' do
      sub_service_request.organization.subsidy_map.update_attributes(
          max_dollar_cap: 100,
          max_percentage: 100)

      session[:service_request_id] = service_request.id
      get :service_subsidy, id: service_request.id

      expect(assigns(:subsidies).map { |s| s.class}).to eq [ Subsidy ]
    end

    context 'with subsidy maps' do
      let!(:core_subsidy_map)     { create(:subsidy_map, organization_id: core.id) }
      let!(:provider_subsidy_map) { create(:subsidy_map, organization_id: provider.id) }
      let!(:program_subsidy_map)  { subsidy_map }

      it 'should not create a new subsidy if the ssr does not have a subsidy and it not is eligible for subsidy' do
        # destroy the subsidy; we want to ensure that #service_subsidy
        # doesn't create a subsidy
        sub_service_request.subsidy.destroy

        core.build_subsidy_map
        provider.build_subsidy_map
        program.build_subsidy_map

        core.subsidy_map.update_attributes!(
            max_dollar_cap: 0,
            max_percentage: 0)
        provider.subsidy_map.update_attributes!(
            max_dollar_cap: 0,
            max_percentage: 0)
        program.subsidy_map.update_attributes!(
            max_dollar_cap: 0,
            max_percentage: 0)

        # make sure before we start the test that the ssr is not
        # eligible for subsidy
        expect(sub_service_request.eligible_for_subsidy?).not_to eq nil

        # call service_subsidy
        session[:service_request_id] = service_request.id
        get :service_subsidy, id: service_request.id

        # Now the ssr should not have a subsidy
        sub_service_request.reload
        subsidy = sub_service_request.subsidy
        expect(subsidy).to eq nil

        expect(assigns(:subsidies)).to eq [ ]
      end
    end
  end

  describe 'GET navigate' do
    # TODO: wow, this method is complicated.  I'm not sure what to test
    # for.
  end

  describe 'POST navigate' do
    # TODO: wow, this method is complicated.  I'm not sure what to test
    # for.
  end
end
