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

class CatalogManager::InstitutionsController < CatalogManager::AppController
  respond_to :js, :html, :json
  layout false

  def create
    @institution = Institution.create({:name => params[:name], :abbreviation => params[:name], :is_available => false})
    @user.catalog_manager_rights.create :organization_id => @institution.id
 
    respond_with [:catalog_manger, @institution]
  end

  def show
    @institution = Institution.find(params[:id])
    @institution.setup_available_statuses
  end

  def update
    @institution = Institution.find(params[:id])

    unless params[:institution][:tag_list]
      params[:institution][:tag_list] = ""
    end
    
    params[:institution].delete(:id)
    if @institution.update_attributes(params[:institution])
      flash[:notice] = "#{@institution.name} saved correctly."
    else
      flash[:alert] = "Failed to update #{@institution.name}."
    end
    
    @institution.setup_available_statuses
    @entity = @institution
    respond_with @institution, :location => catalog_manager_institution_path(@institution)
  end
end