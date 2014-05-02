module SubsidiesHelper

  def display_requested_funding direct_cost, contribution
    # multiply contribution by 100 to convert to cents
    rf = direct_cost - contribution rescue 0
    currency_converter(rf)
  end

  def calculate_subsidy_percentage direct_cost, contribution, subsidy
    # multiply contribution by 100 to convert to cents
    return 0 if direct_cost == 0.0
    funded_amount = direct_cost - contribution rescue 0
    percent = ((funded_amount / direct_cost) * 100).round(2)
    subsidy.update_attributes(:admin_percent_subsidy => percent)

    percent
  end
end
