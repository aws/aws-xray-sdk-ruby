module XRay
  # The interface of context management for the X-Ray recorder.
  module Context
    # @param [Entity] entity The entity to be stored in the context.
    def store_entity(entity:)
      raise 'Not implemented'
    end

    def current_entity
      raise 'Not implemented'
    end

    def clear!
      raise 'Not implemented'
    end

    # Put current active entity to the new context storage.
    def inject_context(entity, target_ctx: nil)
      raise 'Not implemented'
    end

    def handle_context_missing
      raise 'Not implemented'
    end
  end
end
