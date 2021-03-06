require 'rails_helper'

RSpec.describe 'SPARCCWF::APIv1', type: :request do

  describe 'GET /v1/visits.json' do

    before do
      Visit.skip_callback(:save, :after, :set_arm_edited_flag_on_subjects)

      5.times do
        visit = build(:visit)
        visit.save validate: false
      end

      @visit_ids = Visit.pluck(:id)
    end

    context 'with ids' do

      before { cwf_sends_api_get_request_for_resources('visits', 'shallow', @visit_ids.pop(4)) }

      context 'success' do

        it 'should respond with an HTTP status code of: 200' do
          expect(response.status).to eq(200)
        end

        it 'should respond with content-type: application/json' do
          expect(response.content_type).to eq('application/json')
        end

        it 'should respond with a Visits root object' do
          expect(response.body).to include('"visits":')
        end

        it 'should respond with an array of Visits' do
          parsed_body = JSON.parse(response.body)

          expect(parsed_body['visits'].length).to eq(4)
        end
      end
    end

    context 'request for :shallow records' do

      before { cwf_sends_api_get_request_for_resources('visits', 'shallow', @visit_ids) }

      it 'should respond with an array of :sparc_ids' do
        parsed_body = JSON.parse(response.body)

        expect(parsed_body['visits'].map(&:keys).flatten.uniq.sort).to eq(['sparc_id', 'callback_url'].sort)
      end
    end

    context 'request for :full records' do

      before { cwf_sends_api_get_request_for_resources('visits', 'full', @visit_ids) }

      it 'should respond with an array of visits and their attributes' do
        parsed_body         = JSON.parse(response.body)
        expected_attributes = build(:visit).attributes.
                                keys.
                                reject { |key| ['id', 'created_at', 'updated_at', 'deleted_at'].include?(key) }.
                                push('callback_url', 'sparc_id').
                                sort

        expect(parsed_body['visits'].map(&:keys).flatten.uniq.sort).to eq(expected_attributes)
      end
    end

    context 'request for :full_with_shallow_reflections records' do

      before { cwf_sends_api_get_request_for_resources('visits', 'full_with_shallow_reflections', @visit_ids) }

      it 'should respond with an array of visits and their attributes and their shallow reflections' do
        parsed_body         = JSON.parse(response.body)
        expected_attributes = build(:visit).attributes.
                                keys.
                                reject { |key| ['id', 'created_at', 'updated_at', 'deleted_at'].include?(key) }.
                                push('callback_url', 'sparc_id', 'line_items_visit', 'visit_group').
                                sort

        expect(parsed_body['visits'].map(&:keys).flatten.uniq.sort).to eq(expected_attributes)
      end
    end
  end
end
