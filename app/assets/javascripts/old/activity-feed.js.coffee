SubstoryModel = Backbone.Model.extend
  decoratedJSON: ->
    console.log "test"
    json = @toJSON()
    json["type"] = {}
    json["type"][@get("substory_type")] = true
    return json

StoryModel = Backbone.Model.extend
  initialize: ->
    substories = @get("substories")

    substoriesCollection = new SubstoryCollectionClass
    @set "substories", substoriesCollection

    that = this
    _.each substories, (x) -> x.user = that.get("user")
    
    substoriesCollection.add substories

SubstoryCollectionClass = Backbone.Collection.extend
  model: SubstoryModel
  comparator: (substory) ->
    return -moment(substory.get("created_at")).unix()

StoryCollection = new Backbone.Collection
StoryCollection.model = StoryModel
StoryCollection.comparator = (story) ->
  return -moment(story.get("updated_at")).unix()

StoryView = Backbone.View.extend
  initialize: -> @expanded = false
  template: HandlebarsTemplates["stories/story"]
  
  render: ->
    if @model.get("story_type") == "comment"
      if @model.get("poster").nb and (not currentUser or (currentUser and not (currentUser.admin or currentUser.nb)))
        return
    
    json = @model.toJSON()
    json["type"] = {}
    json["type"][@model.get("story_type")] = true
    
    json["morethantwo"] = json["substories"].length > 2
    json["additional"] = json["substories"].length - 2
      
    json["substories"] = json["substories"].map (s) ->
      q = s.toJSON()
      q["type"] = {}
      q["type"][s.get("substory_type")] = true
      return q
    
    unless @expanded
      json["substories"] = json["substories"].slice(0, 2)
    
    json["expanded"] = @expanded
    
    @$el.html @template(json)
    
    that = this
    @$el.find("a.show-more").click ->
      that.toggleExpand()

    if currentUser
      @$el.find("a#remove").click ->
        id = $(this).attr("data-id")
        link = this
        $.post "/api/v1/users/" + currentUser.param + "/feed/remove", {substory_id: id}, (d) ->
          if d
            if that.model.get("substories").length == 1
              $(link).closest("li.feed-item").fadeOut()
            else
              $(link).closest(".substory").fadeOut()
          else
            alert "Something went wrong. Please try again later."
            
      if @model.get("story_type") == "comment"
        if @model.get("poster").nb and currentUser.admin
          @$el.addClass 'ninja-ban'
      
  toggleExpand: ->
    @expanded = !@expanded
    @render()
    
StoryCollectionViewClass = Backbone.View.extend
  initialize: ->
    _(this).bindAll 'add', 'remove'
    @views = {}
    @collection.bind 'add', @add
    @collection.bind 'remove', @remove
    @loadedAll = false
    @fetchInProgress = false
    @page = 1
  add: (story) ->
    @views[story.cid] = new StoryView
      model: story
  remove: (story) ->
    delete @views[story.cid]
  render: ->
    @$el.empty()
    that = this
    @collection.each (model) ->
      view = that.views[model.cid]
      view.render()
      that.$el.append view.$el
    $(".activity-feed").append @$el
  fetchMore: (baseURL) ->
    unless @loadedAll or @fetchInProgress
      @fetchInProgress = true
      that = this
      $.ajax baseURL + "page=" + @page,
        dataType: "json"
        error: -> that.fetchInProgress = false
        success: (feedItems) ->
          that.page += 1
          that.fetchInProgress = false
          if feedItems.length == 0
            that.loadedAll = true
            $(".activity-feed-spinner").hide()
          that.addStories feedItems
  addStories: (stories) ->
    @collection.add stories
    @render()

@StoryCollectionView = new StoryCollectionViewClass
  collection: StoryCollection
  
@getUserFeedItems = (user) ->
  StoryCollectionView.fetchMore "/api/v1/users/" + user + "/feed?"