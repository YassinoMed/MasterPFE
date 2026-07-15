output "etcd_backup_volume_ids" {
  description = "IDs of the EBS volumes created for etcd backup"
  value       = aws_ebs_volume.etcd_backup[*].id
}

output "postgres_volume_id" {
  description = "ID of the EBS volume created for postgres"
  value       = aws_ebs_volume.postgres_data.id
}

output "qdrant_volume_id" {
  description = "ID of the EBS volume created for qdrant"
  value       = aws_ebs_volume.qdrant_data.id
}
