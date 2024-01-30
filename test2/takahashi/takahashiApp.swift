//
//  appl.swift
//  takahashi
//
//  Created by SuMiTS&S 開発第一部 on 2023/12/08.
//

import Combine
import Foundation

import SwiftUI

struct Subtask: Identifiable, Codable {
    var id = UUID()
    var title: String
    var deadline: Date?
}

struct Task: Identifiable, Codable {
    var id = UUID()
    var title: String
    var subtasks: [Subtask]
}

class TaskManager: ObservableObject {
    @Published var tasks: [Task] = []
    
    private let tasksKey = "tasks"
    
    init() {
        if let storedTasks = UserDefaults.standard.data(forKey: tasksKey) {
            let decoder = JSONDecoder()
            if let decodedTasks = try? decoder.decode([Task].self, from: storedTasks) {
                tasks = decodedTasks
                validateTasks()
            }
        }
    }
    
    func validateTasks() {
        for task in tasks {
            for subtask in task.subtasks {
                guard tasks.contains(where: { $0.subtasks.contains(where: { $0.id == subtask.id }) }) else {
                    print("Inconsistency found: Task \(task.title) and Subtask \(subtask.title) are not properly related.")
                    DispatchQueue.main.async {
                        // Handle inconsistency, e.g., show an alert
                    }
                    break
                }
            }
        }
    }
    
    func saveTasks() {
        let encoder = JSONEncoder()
        if let encodedTasks = try? encoder.encode(tasks) {
            UserDefaults.standard.set(encodedTasks, forKey: tasksKey)
        }
    }
    
    func deleteSubtask(task: Task, subtask: Subtask) {
            if let taskIndex = tasks.firstIndex(where: { $0.id == task.id }),
               let subtaskIndex = tasks[taskIndex].subtasks.firstIndex(where: { $0.id == subtask.id }) {
                tasks[taskIndex].subtasks.remove(at: subtaskIndex)

                // タスクが空になった場合、タスクも削除
                if tasks[taskIndex].subtasks.isEmpty {
                    tasks.remove(at: taskIndex)
                }

                saveTasks()
            }
        }
    }

struct SubtaskRow: View {
    var subtask: Subtask
    var onDelete: () -> Void

    var body: some View {
        HStack {
            Text(subtask.title)
            Spacer()
            if let deadline = subtask.deadline {
                Text("\(deadline, formatter: dateFormatter)")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: { onDelete() }) {
                Text("Delete")
            }
        }
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
}
struct TaskRow: View {
    var task: Task
    var onDeleteSubtask: (Task, Subtask) -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Text(task.title)
                .font(.headline)

            ForEach(task.subtasks) { subtask in
                SubtaskRow(subtask: subtask) {
                    onDeleteSubtask(task, subtask)
                }
            }
        }
    }
}

struct TaskListView: View {
    @EnvironmentObject var taskManager: TaskManager
    @State private var isAddingTask = false

    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(taskManager.tasks) { task in
                        Section(header: Text(task.title).font(.headline)) {
                            ForEach(task.subtasks) { subtask in
                                SubtaskRow(subtask: subtask) {
                                    taskManager.deleteSubtask(task: task, subtask: subtask)
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteTask)
                }
                .listStyle(InsetListStyle())
            }
            .navigationBarTitle("タスク管理", displayMode: .inline)
            .navigationBarItems(
                trailing:
                    Button(action: {
                        isAddingTask = true
                    }) {
                        Text("追加")
                    }
            )
            .sheet(isPresented: $isAddingTask) {
                AddTaskView(isPresented: $isAddingTask)
                    .environmentObject(taskManager)
            }
            .onAppear {
                taskManager.validateTasks()
            }
        }
    }

    private func deleteTask(offsets: IndexSet) {
        taskManager.tasks.remove(atOffsets: offsets)
        taskManager.saveTasks()
    }
}

struct AddTaskView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var taskManager: TaskManager

    @State private var selectedTaskIndex: Int = 0
    @State private var isNewTaskSelected: Bool = false
    @State private var newTaskTitle = ""
    @State private var newSubtaskTitle = ""
    @State private var selectedDate = Date()

    var body: some View {
        NavigationView {
            VStack {
                Picker("Select Task", selection: $selectedTaskIndex) {
                    ForEach(0..<taskManager.tasks.count, id: \.self) { index in
                        Text(taskManager.tasks[index].title).tag(index)
                    }
                    Text("新規").tag(-1)
                }
                .pickerStyle(MenuPickerStyle())
                .onChange(of: selectedTaskIndex) { newIndex in
                    isNewTaskSelected = newIndex == -1
                }
                .padding()

                if isNewTaskSelected {
                    TextField("New Task", text: $newTaskTitle)
                        .padding()
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .maxLength(30)
                } else {
                    TextField("New Subtask", text: $newSubtaskTitle)
                        .padding()
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .maxLength(30)
                }

                DatePicker("Deadline", selection: $selectedDate, displayedComponents: .date)
                    .padding()

                Button(action: {
                    if isNewTaskSelected {
                        let newTask = Task(title: newTaskTitle, subtasks: [])
                        taskManager.tasks.append(newTask)
                    }
                        else {
                        let newSubtask = Subtask(title: newSubtaskTitle, deadline: selectedDate)
                        taskManager.tasks[selectedTaskIndex].subtasks.append(newSubtask)
                    }
                    taskManager.saveTasks()
                    isPresented = false
                }) {
                    Text(isNewTaskSelected ? "Add Task" : "Add Subtask")
                }
                .padding()
            }
            .navigationTitle(isNewTaskSelected ? "Add Task" : "Add Subtask")
        }
    }
}
extension View {
    func maxLength(_ maxLength: Int) -> some View {
        return modifier(MaxLengthModifier(maxLength: maxLength))
    }
}

struct MaxLengthModifier: ViewModifier {
    let maxLength: Int
    

    func body(content: Content) -> some View {
        content
        
           // .onReceive(Just(content)) {
                //newValue in
             //   let value = newValue as! Text
             //   if value.wrappedValue.count > maxLength {
             //       value.wrappedValue = String(value.wrappedValue.prefix(maxLength))
             //   }
          //  }
    //}
}

@main
struct TaskManagerApp: App {
    @StateObject private var taskManager = TaskManager()

    var body: some Scene {
        WindowGroup {
            TaskListView()
                .environmentObject(taskManager)
        }
    }
}

}
