from django.db import models

# Create your models here.

class Task(models.Model):
    id = models.AutoField(primary_key=True)
    title = models.CharField(max_length=20)
    description = models.TextField()
    completed = models.BooleanField(default=False) 
    # Add any other fields you need
    

    def __str__(self):
        return self.title
    






