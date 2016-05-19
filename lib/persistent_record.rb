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
      [:restore, :force_destroy].each do |callback_name|
        source.define_callbacks callback_name
        source.define_singleton_method("before_#{callback_name}") do |*args, &block|
          set_callback(callback_name, :before, *args, &block)
        end
        source.define_singleton_method("around_#{callback_name}") do |*args, &block|
          set_callback(callback_name, :around, *args, &block)
        end
        source.define_singleton_method("after_#{callback_name}") do |*args, &block|
          set_callback(callback_name, :after, *args, &block)
        end
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

  def force_destroy!
    transaction do
      run_callbacks(:force_destroy) do
        dependent_reflections = self.class.reflections.select do |name, reflection|
          reflection.options[:dependent] == :destroy
        end
        if dependent_reflections.any?
          dependent_reflections.each do |name|
            associated_records = self.send(name)
            associated_records = associated_records.with_discarded if associated_records.respond_to?(:with_discarded)
            associated_records.each(&:force_destroy!)
          end
        end
        default_destroy
      end
    end
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

    alias_method :default_destroy, :destroy

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

    unless connection.column_exists?(table_name, record_deleted_at_column)
      raise(ActiveModel::MissingAttributeError)
    end

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
