resource "azurerm_virtual_machine_extension" "custom_script" {
  name                 = "wait_for_domain"
  location             = azurerm_virtual_machine.sql.location
  resource_group_name  = var.resource_group_name
  virtual_machine_name = azurerm_virtual_machine.sql.name
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"

  settings = <<SETTINGS
    {
        "commandToExecute": "powershell.exe  do {} Until (Test-Connection ${var.active_directory_domain} -Quiet -Count 1)"
    }
SETTINGS
   depends_on = [azurerm_virtual_machine.sql]

}

resource "null_resource" "delay" {
  
  #Due to Domain Join Intermittent problem 
  provisioner "local-exec" {
    command     = "Start-Sleep 20"
    interpreter = ["PowerShell", "-Command"]
  }  
  depends_on = [azurerm_virtual_machine_extension.custom_script]
}