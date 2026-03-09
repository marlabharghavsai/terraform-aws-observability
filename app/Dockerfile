# Use an official Python runtime as a parent image
FROM python:3.9-slim-buster

# Add a non-root user (Security Best Practice)
RUN adduser --system --group appuser

# Set the working directory in the container
WORKDIR /app

# Copy the current directory contents into the container at /app
COPY . /app

# Change ownership of the app to the non-root user
RUN chown -R appuser:appuser /app

# Expose port (80)
EXPOSE 80

# Switch to the non-root user
USER appuser

# Run app.py when the container launches
CMD ["python", "app.py"]
