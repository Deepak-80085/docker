from django.urls import path
from tasks import views

urlpatterns = [

        path('', views.task_list, name='task_list'    ),
        path('create/', views.task_create, name='task_create'),
        path('update/<int:id>/', views.task_update, name='task_update'),
        path('delete/<int:id>/', views.task_delete, name='task_delete'),
    ]

