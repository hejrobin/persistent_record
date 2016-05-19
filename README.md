# PersistentRecord

Introduces soft deletions for ActiveRecord. Heavily inspired by [radar/paranoia](https://github.com/radar/paranoia).

## Installation

	gem 'persistent_record', github: 'lessthanthree/persistent_record'

## Usage

Migrate your models by adding a "deleted_at" timestamp, `rails generate migration AddDeletedAtColumnToModels deleted_at:datetime:index`

	class YourModel < ActiveRecord::Base

		acts_as_persistent

	end


## Deprecation Warning

* `zap!` is now an alias for `force_destroy!`, will be removed in 1.0.
