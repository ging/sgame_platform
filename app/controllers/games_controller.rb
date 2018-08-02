class GamesController < ApplicationController
  before_filter :authenticate_user!, :only => [:new, :create, :edit, :update]
  before_filter :allow_iframe_requests
  load_and_authorize_resource :except => [:sgame_api, :metadata]
  skip_authorization_check :only => [:sgame_api]

 
  #############
  # REST methods
  #############

  def index
    redirect_to "/"
  end

  def show
    @game = Game.find(params[:id])
    @suggestions = RecommenderSystem.suggestions({:n => 6, :lo_profile => @game.profile, :settings => {:preselection_filter_by_resource_types => ["Game"]}})
    respond_to do |format|
      format.html {
        render
      }
      format.full {
        render :layout => 'game'
      }
      format.json {
        render :json => @game.json
      }
      format.scorm {
        if (can? :read, @game)
          scormVersion = (params["version"].present? and ["12","2004"].include?(params["version"])) ? params["version"] : "2004"
          @game.to_scorm(self,scormVersion)
          send_file @game.scormFilePath(scormVersion), :type => 'application/zip', :disposition => 'attachment', :filename => ("scorm" + scormVersion + "-#{@game.id}.zip")
        else
          render :nothing => true, :status => 500
        end
      }
    end
  end

  def new
    @game = Game.new
    @game_templates = (GameTemplate.where(:certified => true) + current_user.game_templates).uniq
    @scormfiles = current_user.scormfiles
    
    respond_to do |format|
      format.html { 
        render 
      }
    end
  end

  def edit
    @game = Game.find(params[:id])
    respond_to do |format|
      format.html { 
        render 
      }
    end
  end

  def create
    params[:game].permit!
    
    @game = Game.new({:editor_data => params[:game][:editor_data].to_json})
    @game.owner_id = current_user.id

    if(params[:game][:draft] and params[:game][:draft] == "true")
      @game.draft = true
    else
      @game.draft = false
    end

    #Fill game fields from editor_data
    @game.fill_from_editor_data

    @game.valid?


    if @game.errors.blank? and @game.save
      @game.create_mappings_from_editor_data
    else
      errorMsg = @game.errors.full_messages.to_sentence
    end
   
    respond_to do |format|
      format.json {
        if @game.persisted?
          render :json => { 
            :gamePath => game_path(@game),
            :editPath => edit_game_path(@game),
            :id => @game.id
          },
          :status => 200
        else
          render :json => { 
            :errorMsg => errorMsg
          },
          :status => 400
        end
      }
    end
  end

  def update
    #TODO
  end

  def destroy
    @game = Game.find(params[:id])
    @game.destroy
    respond_to do |format|
      format.all { redirect_to user_path(current_user) }
    end
  end


  #############
  # Custom methods
  #############

  def sgame_api
    redirect_to "/sgame_api/SGAME.js"
  end

  def metadata
    game = Game.find_by_id(params[:id])
    authorize! :show, game
    respond_to do |format|
      format.any {
        unless game.nil?
          xmlMetadata = Game.generate_LOM_metadata(game,{:id => Rails.application.routes.url_helpers.game_url(game), :LOMschema => params[:LOMschema] || "custom"})
          render :xml => xmlMetadata.target!, :content_type => "text/xml"
        else
          xmlMetadata = ::Builder::XmlMarkup.new(:indent => 2)
          xmlMetadata.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
          xmlMetadata.error("Game not found")
          render :xml => xmlMetadata.target!, :content_type => "text/xml", :status => 404
        end
      }
    end
  end


  private

  def game_params
    params.require(:game).permit(:editor_data,:draft)
  end

end