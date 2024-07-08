import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job

# Get job arguments, get datalist https://www.datablist.com/learn/csv/download-sample-csv-files
args = getResolvedOptions(sys.argv, ['JOB_NAME'])

# Initialize SparkContext, GlueContext, and SparkSession
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session

# Create Glue job
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# Script generated for node AWS Glue Data Catalog
AWSGlueDataCatalog_node = glueContext.create_dynamic_frame.from_catalog(
    database="org-report", 
    table_name="tutorial_source_data_bucket", 
    transformation_ctx="AWSGlueDataCatalog_node"
    )

# Script generated for node Change Schema
ChangeSchema_node = ApplyMapping.apply(
    frame=AWSGlueDataCatalog_node, 
    mappings=[
        ("index", "long", "index", "long"), 
        ("organization id", "string", "organization id", "string"), 
        ("name", "string", "name", "string"), 
        ("website", "string", "website", "string"), 
        ("country", "string", "country", "string"), 
        ("description", "string", "description", "string"), 
        ("founded", "long", "founded", "long"), 
        ("industry", "string", "industry", "string"), 
        ("number of employees", "long", "number of employees", "long")], 
        transformation_ctx="ChangeSchema_node")

# Script generated for node Amazon S3
AmazonS3_node = glueContext.write_dynamic_frame.from_options(
    frame=ChangeSchema_node, 
    connection_type="s3", 
    format="csv", 
    connection_options={
        "path": "s3://tutorial-target-data-bucket", 
        "partitionKeys": []}, 
        transformation_ctx="AmazonS3_node"
        )

job.commit()