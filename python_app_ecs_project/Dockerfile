# Use the official Python image
FROM python:3-alpine3.15

# Set the working directory in the container
WORKDIR /app

# Copy the application files to the container
COPY app.py /app/

# Install dependencies
RUN pip install flask

# Expose port 80 for the Flask app
EXPOSE 80

# Command to run the application
CMD ["python", "app.py"]