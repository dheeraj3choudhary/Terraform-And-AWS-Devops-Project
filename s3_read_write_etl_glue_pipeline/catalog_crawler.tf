# Create Glue Data Catalog Database
resource "aws_glue_catalog_database" "org_report_database" {
  name         = "org-report"
  location_uri = "${aws_s3_bucket.tutorial-source-data-bucket.id}/"
}

# Create Glue Crawler
resource "aws_glue_crawler" "org_report_crawler" {
  name          = "org-report-crawler"
  database_name = aws_glue_catalog_database.org_report_database.name
  role          = aws_iam_role.glue_service_role.name
  s3_target {
    path = "${aws_s3_bucket.tutorial-source-data-bucket.id}/"
  }
  schema_change_policy {
    delete_behavior = "LOG"
  }
  configuration = <<EOF
{
  "Version":1.0,
  "Grouping": {
    "TableGroupingPolicy": "CombineCompatibleSchemas"
  }
}
EOF
}
resource "aws_glue_trigger" "org_report_trigger" {
  name = "org-report-trigger"
  type = "ON_DEMAND"
  actions {
    crawler_name = aws_glue_crawler.org_report_crawler.name
  }
}