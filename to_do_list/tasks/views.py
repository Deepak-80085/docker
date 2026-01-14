from django.shortcuts import render, redirect
from tasks.models import Task

# Create your views here.
def task_list(req):
    tasks = Task.objects.all()
    context = {
        'tasks': tasks,
    }
    return render(req, 'tasks/task_list.html', context)


def task_create(req):
    if req.method == 'POST':
        title = req.POST.get('title')
        des = req.POST.get('description')
        completed = req.POST.get('completed') == 'on'
        task = Task(title=title,description=des,completed=completed)
        task.save()
        return redirect('task_list')
    return render(req, 'tasks/task_create.html')

def task_update(req, id):
    task = Task.objects.get(id=id)
    if req.method == 'POST':
        title = req.POST.get('title')
        des = req.POST.get('description')
        completed = req.POST.get('completed') == 'on'
        task.title = title
        task.description = des
        task.completed = completed
        task.save()
        return redirect('task_list')
    return render(req, 'tasks/task_update.html', {'task': task})

def task_delete(req, id):
    task = Task.objects.get(id=id)
    if req.method == 'POST':
        task.delete()
        return redirect('task_list')
    return render(req, 'tasks/task_delete.html', {'task': task})


    
