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

module CatalogManager::ServicesHelper
  def display_service_user_rights user, form_name, organization
    if user.can_edit_entity? organization, true
      render form_name
    else
      content_tag(:h1, "Sorry, you are not allowed to access this page.") +
      content_tag(:h3, "Please contact your system administrator.", :style => 'color:#999')
    end
  end

  def display_otf_attributes pricing_map
    if pricing_map
      attributes = ""
      if pricing_map.is_one_time_fee
        if pricing_map.otf_unit_type == "N/A"
          attributes = "# " + pricing_map.quantity_type
        else
          attributes = "# " + pricing_map.quantity_type + " /  # " + pricing_map.otf_unit_type
        end
      end

      attributes
    end
  end

 
  def per_patient_display_style pricing_map
    style = ""

    if pricing_map
      if pricing_map.is_one_time_fee
        style = "display:none;"
      end
    else
      style = ""
    end

    style
  end
end