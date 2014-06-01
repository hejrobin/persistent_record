require "persistent_record/version"
require 'active_record' unless defined? ActiveRecord



module PersistentRecord

  def self.included(source)
    source.extend Query
    source.extend Callbacks
  end

  module Query

    def persistent?
      true
    end

    def with_discarded
      if ActiveRecord::VERSION::STRING >= "4.1"
        unscope where: record_deleted_at_column
      else
        all.tap { |x| x.default_scoped = false }
      end
    end

    def only_discarded
      with_discarded.where.not(record_deleted_at_column => nil)
    end

    alias :discarded :with_discarded
    alias :discarded! :only_discarded

    def restore(id, options = {})
      if id.is_a?(Array)
        id.map { |one_id| restore(one_id, options) }
      else
        only_discarded.find(id).restore!(options)
      end
    end

  end

  module Callbacks

    def self.extended(source)

      source.define_callbacks :restore

      source.define_singleton_method("before_restore") do |*args, &block|
        set_callback(:restore, :before, *args, &block)
      end

      source.define_singleton_method("around_restore") do |*args, &block|
        set_callback(:restore, :around, *args, &block)
      end

      source.define_singleton_method("after_restore") do |*args, &block|
        set_callback(:restore, :after, *args, &block)
      end

    end

  end

  def destroy
    callbacks_result = run_callbacks(:destroy) { touch_record_deleted_at_column(true) }
    callbacks_result ? self : false
  end

  if ActiveRecord::VERSION::STRING >= "4.1"
    def destroy!
      discarded? ? super : destroy || raise(ActiveRecord::RecordNotDestroyed)
    end
  end

  def delete
    return if new_record?
    touch_record_deleted_at_column(false)
  end

  alias :discard :destroy

  def restore!(options = {})
    ActiveRecord::Base.transaction do
      run_callbacks(:restore) do
        update_column record_deleted_at_column, nil
        restore_associated_records if options[:recursive]
      end
    end
  end

  def discarded?
    !!send(record_deleted_at_column)
  end

  private

  def touch_record_deleted_at_column(with_transaction = false)
    unless self.frozen?
      if with_transaction
        with_transaction_returning_status { touch(record_deleted_at_column) }
      else
        touch(record_deleted_at_column)
      end
    end
  end

  def restore_associated_records

    destroyed_associations = self.class.reflect_on_all_associations.select do |association|
      association.options[:dependent] == :destroy
    end

    destroyed_associations.each do |association|
      association_data = send(association.name)
      unless association_data.nil?
        if association_data.persistent?
          if association.collection?
            association_data.only_discarded.each { |record| record.restore(:recursive => true) }
          else
            association_data.restore(:recursive => true)
          end
        end
      end
    end

  end

end

class ActiveRecord::Base

  def self.acts_as_persistent(options = {})

    alias :destroy! :destroy
    alias :delete! :delete

    def zap!
      dependent_reflections = self.reflections.select do |name, reflection|
        reflection.options[:dependent] == :destroy
      end
      if dependent_reflections.any?
        dependent_reflections.each do |name|
          associated_records = self.send(name)
          associated_records = associated_records.with_discarded if associated_records.respond_to?(:with_discarded)
          associated_records.each(&:zap!)
        end
      end
      destroy!
    end

    include PersistentRecord

    class_attribute :record_deleted_at_column

    self.record_deleted_at_column = options[:column] || :deleted_at
    default_scope { where(record_deleted_at_column => nil) }

    before_restore {
      self.class.notify_observers(:before_restore, self) if self.class.respond_to?(:notify_observers)
    }

    after_restore {
      self.class.notify_observers(:after_restore, self) if self.class.respond_to?(:notify_observers)
    }

  end

  def self.persistent?
    false
  end

  def persistent?
    self.class.persistent?
  end

  def persisted?
    persistent? ? !new_record? : super
  end

  private

  def record_deleted_at_column
    self.class.record_deleted_at_column
  end

end
