import SwiftUI
import Foundation

struct UserManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var users: [String] = AppUserStore.loadUsers()
    @State private var selectedUser: String = AppUserStore.loadSelectedUser()
    @State private var showAddPrompt = false
    @State private var newUserName = ""

    @State private var renameTarget: String?
    @State private var renameText = ""
    @State private var showRenamePrompt = false

    @State private var deleteTarget: String?
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            List {
                Section(L("user_mgmt_section_accounts")) {
                    ForEach(users, id: \.self) { user in
                        HStack(spacing: 12) {
                            Button {
                                selectedUser = user
                                AppUserStore.setSelectedUser(user)
                            } label: {
                                HStack {
                                    Text(user)
                                        .amgiFont(.body)
                                        .foregroundStyle(Color.amgiTextPrimary)
                                    Spacer()
                                    if selectedUser == user {
                                        Label(L("common_selected"), systemImage: "checkmark.circle.fill")
                                            .labelStyle(.iconOnly)
                                            .amgiStatusBadge(.positive)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            Menu {
                                Button {
                                    renameTarget = user
                                    renameText = user
                                    showRenamePrompt = true
                                } label: {
                                    Label(L("user_mgmt_rename"), systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    deleteTarget = user
                                    showDeleteConfirm = true
                                } label: {
                                    Label(L("common_delete"), systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color.amgiTextSecondary)
                                    .frame(width: 28, height: 28)
                            }
                        }
                        .listRowBackground(Color.amgiSurfaceElevated)
                        .contextMenu {
                            Button {
                                renameTarget = user
                                renameText = user
                                showRenamePrompt = true
                            } label: {
                                Label(L("user_mgmt_rename"), systemImage: "pencil")
                            }

                            Button(role: .destructive) {
                                deleteTarget = user
                                showDeleteConfirm = true
                            } label: {
                                Label(L("common_delete"), systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteTarget = user
                                showDeleteConfirm = true
                            } label: {
                                Label(L("common_delete"), systemImage: "trash")
                            }

                            Button {
                                renameTarget = user
                                renameText = user
                                showRenamePrompt = true
                            } label: {
                                Label(L("user_mgmt_rename"), systemImage: "pencil")
                            }
                            .tint(Color.amgiAccent)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.amgiBackground)
            .navigationTitle(L("user_mgmt_title"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("common_done")) {
                        dismiss()
                    }
                    .amgiToolbarTextButton(tone: .neutral)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        newUserName = ""
                        showAddPrompt = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .alert(L("user_mgmt_add_title"), isPresented: $showAddPrompt) {
            TextField(L("user_mgmt_username_placeholder"), text: $newUserName)
            Button(L("common_cancel"), role: .cancel) {}
            Button(L("user_mgmt_add_button")) {
                let trimmed = newUserName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                if !users.contains(trimmed) {
                    users.append(trimmed)
                    AppUserStore.saveUsers(users)
                }
                selectedUser = trimmed
                AppUserStore.setSelectedUser(trimmed)
            }
        }
        .alert(L("user_mgmt_rename_title"), isPresented: $showRenamePrompt) {
            TextField(L("user_mgmt_new_username_placeholder"), text: $renameText)
            Button(L("common_cancel"), role: .cancel) {}
            Button(L("common_save")) {
                guard let old = renameTarget else { return }
                let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                if let idx = users.firstIndex(of: old) {
                    users[idx] = trimmed
                    AppUserStore.saveUsers(users)
                }
                if selectedUser == old {
                    selectedUser = trimmed
                    AppUserStore.setSelectedUser(trimmed)
                }
            }
        }
        .alert(L("user_mgmt_delete_confirm1_title"), isPresented: $showDeleteConfirm) {
            Button(L("common_cancel"), role: .cancel) {
                deleteTarget = nil
            }
            Button(L("common_delete"), role: .destructive) {
                guard let target = deleteTarget else { return }
                performDeleteUser(target)
                deleteTarget = nil
            }
        } message: {
            Text(L("user_mgmt_delete_confirm2_msg"))
        }
    }

    private func performDeleteUser(_ target: String) {
        let wasSelected = (selectedUser == target)
        users.removeAll { $0 == target }
        if users.isEmpty {
            users = [L("user_mgmt_default_user")]
        }
        AppUserStore.saveUsers(users)
        if wasSelected {
            selectedUser = users[0]
            AppUserStore.setSelectedUser(users[0])
        } else {
            let folderURL = AppUserStore.collectionURLs(for: target).directory
            try? FileManager.default.removeItem(at: folderURL)
        }
    }
}
