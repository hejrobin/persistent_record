# Documentation

---

## Fetching records

### `with_discarded`
Returns records including discarded records. Has an alias; `discarded`.

### `only_discarded`
Returns only discarded records. Has an alias; `discarded!`.

### `discarded?`
Validates whether or not record is discarded.

### `discard`
Discards record, alias of `destroy`.

### `restore!`
Restores current discarded record.

### `restore` (*int|array* id, *hash* options = {})
Restores one or several records.

### `zap!`
Deletes record entierly; **removes it from the database**.