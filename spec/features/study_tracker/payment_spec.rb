require 'spec_helper'

describe "payments", js: true do
  let_there_be_lane
  let_there_be_j
  fake_login_for_each_test
  build_service_request_with_project()


  before :each do
    create_visits    
    sub_service_request.update_attributes(in_work_fulfillment: true)
  end

  after :each do
    wait_for_javascript_to_finish
  end

  describe "Entering billing information" do
    before(:each) do
      visit study_tracker_sub_service_request_path(sub_service_request.id)
      click_link "Payments"
    end

    context "with valid information" do
      before :each do 
        within('#payments') do
          within(".fields:last-child") do
            find(".date_submitted input").set("6/13/2013")
            find(".amount_invoiced input").set("500")
            find(".amount_received input").set("400")
            find(".date_received input").set("6/14/2013")
            find(".payment_method select").select("Check")
            find(".details textarea").set("Some details")
          end
          click_button("Save")
        end
      end

      it "saves the record correctly to the database" do
        p = sub_service_request.payments.last

        p.date_submitted.should == Date.new(2013, 6, 13)
        p.amount_invoiced.should == 500.0
        p.amount_received.should == 400.0
        p.date_received.should == Date.new(2013, 6, 14)
        p.payment_method.should == "Check"
        p.percent_subsidy.should == 50.0
        p.details.should == "Some details"
      end

      it "takes you back to the payments tab with the new record rendered" do
        within('#payments') do
          find(".date_submitted input").should have_value("6/13/2013")
          find(".amount_invoiced input").should have_value("500.00")
          find(".amount_received input").should have_value("400.00")
          find(".date_received input").should have_value("6/14/2013")
          find(".payment_method select").should have_value("IIT")
          find(".details textarea").should have_value("Some details")
        end
      end
    end

    context "with invalid information" do
      before :each do 
        within('#payments') do
          within(".fields:last-child") do
            find(".date_submitted input").set("6/13/2013")
            find(".amount_invoiced input").set("abc")
            find(".amount_received input").set("do re me")
            find(".date_received input").set("6/14/2013")
            find(".payment_method select").select("Check")
            find(".details textarea").set("Some details")
          end
          click_button("Save")
        end
      end

      it "shows the payments tab with errors on the appropriate fields" do
        within('#payments') do
          page.should have_content("amount invoiced is not a number");
          page.should have_content("amount received is not a number");
          page.should have_css(".field_with_errors")
        end
      end
    end
  end

  describe "attaching a document to a payment" do
    let(:filename) {  Rails.root.join('spec', 'fixtures', 'files', 'text_document.txt') }

    before(:each) do
      sub_service_request.payments = [FactoryGirl.build(:payment)]
      sub_service_request.save!

      visit study_tracker_sub_service_request_path(sub_service_request.id)
      click_link "Payments"

      within('#payments') do
        within("td.documents") do
          click_link "Add document"
          attach_file(find('input[type="file"]')[:id], filename)
        end
        click_button("Save")
      end
    end


    it "creates a PaymentUpload with the correctly attached file" do
      sub_service_request.payments.last.uploads.first.file.original_filename.should == File.basename(filename)
    end

    it "renders a link to the attached file on subsequent page views" do
      f = sub_service_request.payments.last.uploads.first.file
      within("#payments") do
        page.should have_link(f.original_filename, href: f.url)
      end
    end

  end
end
