class AdminTaskUpload < ApplicationRecord
  belongs_to :admin_task_run

  validates :original_filename, :checksum, :contents, presence: true
  validates :byte_size, numericality: { only_integer: true, greater_than: 0 }
end
