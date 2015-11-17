JbuilderTemplate.class_eval do
  # Caches a collection of objects using fetch_multi, if supported.
  # Requires a block for each item in the array. Accepts optional 'key' attribute in options (e.g. key: 'v1').
  #
  # Example:
  #
  # json.cache_collection! @people, expires_in: 10.minutes do |person|
  #   json.partial! 'person', :person => person
  # end
  def cache_collection!(collection, options = {}, &block)
    if @context.controller.perform_caching
      keys_to_collection_map = _keys_to_collection_map(collection, options)

      if ::Rails.cache.respond_to?(:fetch_multi)
        results = ::Rails.cache.fetch_multi(*keys_to_collection_map.keys, options) do |key|
          _scope { yield keys_to_collection_map[key] }
        end
      else
        results = keys_to_collection_map.map do |key, item|
          ::Rails.cache.fetch(key, options) { _scope { yield item } }
        end
      end

      _process_collection_results(results)
    else
      array! collection, options, &block
    end
  end

  # Conditionally caches a collection of objects depending in the condition given as first parameter.
  #
  # Example:
  #
  # json.cache_collection_if! do_cache?, @people, expires_in: 10.minutes do |person|
  #   json.partial! 'person', :person => person
  # end
  def cache_collection_if!(condition, collection, options = {}, &block)
    condition ?
        cache_collection!(collection, options, &block) :
        array!(collection, options, &block)
  end

  protected

  def _keys_to_collection_map(collection, options)
    key = options.delete(:key)

    collection.inject({}) do |result, item|
      item_key = key.respond_to?(:call) ? key.call(item) : key
      cache_key = item_key ? [item_key, item] : item
      result[_cache_key(cache_key, options)] = item
      result
    end
  end

  def _process_collection_results(results)
    _results = results.class == Hash ? results.values : results
    #support pre 2.0 versions of jbuilder where merge! is still private
    if Jbuilder.instance_methods.include? :merge!
      merge! _results
    elsif Jbuilder.private_instance_methods.include? :_merge
      _merge _results
    else
      _results
    end
  end

end
