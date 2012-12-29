class HomepageController < ApplicationController

  before_filter :save_current_path, :except => :sign_in

  skip_filter :dashboard_only
  skip_filter :not_public_in_private_community, :only => :sign_in

  def index
    session[:selected_tab] = "home"
    listings_per_page = 3
    
    # If requesting a specific page on non-ajax request, we'll ignore that
    # and show the normal front page starting from newest listing
    params[:page] = 1 unless request.xhr? 
    @query = params[:q]
    
    filter_params = params.slice("category", "share_type")
    
    # Check if share_type param contains a value that is actually a listing type
    # both are chosen in one dropdown
    if Listing::VALID_TYPES.include?(filter_params["share_type"])
      filter_params["listing_type"] = filter_params["share_type"]
      filter_params.delete("share_type")
    end
    
    filter_params.reject!{ |key,value| value == "all"} # all means the fliter doesn't need to be included
    
    if @query # Search used
      with = {:open => true} # used for attributes
      conditions = {}        # used indexed fields (as sphinx doesn't support string attributes) 
      
      if filter_params["listing_type"]
         with[:is_request] = true if filter_params["listing_type"].eql?("request")
         with[:is_offer] = true if filter_params["listing_type"].eql?("offer")
      end
      
      if filter_params["category"]
        conditions[:category] = filter_params["category"]
      end
      
      if filter_params["share_type"]
        conditions[:share_type] = filter_params["share_type"]
      end
      
      unless @current_user && @current_user.communities.include?(@current_community)
        with[:visible_to_everybody] = true
      end
      with[:community_ids] = @current_community.id

      @listings = Listing.search(@query, 
                                :include => :listing_images, 
                                :page => params[:page],
                                :per_page => listings_per_page, 
                                :star => true,
                                :with => with,
                                :conditions => conditions
                                )
      
    else # no search used
      
      @listings = Listing.find_with(filter_params, @current_user, @current_community).currently_open.order("created_at DESC").paginate(:per_page => listings_per_page, :page => params[:page])
    end
    
    if request.xhr? # checks if AJAX request
      render :partial => "recent_listing", :collection => @listings, :as => :listing   
    else
      if @current_community.news_enabled?
        @news_items = @current_community.news_items.order("created_at DESC").limit(2)
        @news_item_count = @current_community.news_items.count
      end  
    end
  end

end
