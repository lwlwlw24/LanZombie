// Project: LanZombie
// Created: 2018-05-24

#include "../Function Lib/CoreLibrary.agc"
#include "../Function Lib/GUILibrary.agc"
#include "../Function Lib/LanLibrary.agc"

type HostDataType 
	task as integer[2] // all task storage here
	socre as integer
endtype

type ClientDataType
	task as integer // 
	textID as integer
	buttons as integer[2]
endtype

type GameType
	score as integer
	txtID as integer
	LAN as LANType
	host as HostDataType
	client as ClientDataType
endtype

global taskList as string[4] = ["", "Up", "Down", "Left", "Right"]

global g as GameType

//***************************************
//*** Main program ***
//***************************************

InitialiseScreen(1024,768,"LanZombie", 0xA8A8A8,%1111)


g.LAN = SetNetworkData("Zombie", 1026, 2, 2)
SetUpNetwork(g.LAN, "opbut.png")

//LoadResources()
InitialiseGameVariables()
CreateInitialLayout()

do
	UpdateTask()
	DisplayTask()
	GetUserInput()
	HandleUserInput()
	HandleOther()
	Sync()
loop

//***************************************
//*** Functions ***
//***************************************

function InitialiseGameVariables()
	//taskList = ["", "Up", "Down", "Left", "Right"]
	if IsNetworkHost(g.LAN.netID)
		g.host.socre = 0
		SetNetworkLocalInteger(g.LAN.netID, "score", g.host.socre)
	endif
endfunction
	
function LoadResources()

endfunction

function CreateInitialLayout()
	buttons as integer
	if IsNetworkHost(g.LAN.netID)
		for i = 1 to 2
			g.client.buttons[i] = CreateGUIButton(25+(i-1)*25, 70, 20, 12, "opbut.png", taskList[i] ) 
		next i
	else
		while GetNetworkNumClients(g.LAN.netID) <= 1
			Sleep(50)
		endwhile
		for i = 1 to 2
			g.client.buttons[i] = CreateGUIButton(25+(i-1)*25, 70, 20, 12, "opbut.png", taskList[(GetNetworkMyClientID(g.LAN.netID)-1)*2+i] ) 
		next i
	endif
endfunction

function UpdateTask()
	if IsNetworkHost(g.LAN.netID)
		//generate task if this is host
		if GetNetworkNumClients(g.LAN.netID) > 1
			for i = 1 to GetNetworkNumClients(g.LAN.netID)
				if g.host.task[i] = 0
					g.host.task[i] = Random(1, 4)
					if i <> 1
						SetNetworkLocalInteger(g.LAN.netID, "task", g.host.task[i])
					endif
				endif
			next i
		else 
			Print("No Client Connected")
		endif
		//this is host, get task from local task list
		g.client.task = g.host.task[1]
	//this is a client, get task from host
	else
		g.client.task = GetNetworkClientInteger(g.LAN.netID, 1, "task")
	endif
	
endfunction

function DisplayTask()
	if g.client.textID = 0
		g.client.textID = CreateText(taskList[g.client.task])
		SetTextAlignment(g.client.textID, 1)
		SetTextPosition(g.client.textID, 50, 25)
		SetTextColor(g.client.textID, 0xff, 0, 0, 0xff)
		SetTextSize(g.client.textID, 20)
	else
		SetTextString(g.client.textID,taskList[g.client.task])
	endif
	//Print(taskList[g.client.task])
endfunction

function GetUserInput()
	for i = 1 to 2
		if HandleGUIButton(g.client.buttons[i]) 
			SetNetworkLocalInteger(g.LAN.netID, Str((GetNetworkMyClientID(g.LAN.netID)-1)*2+i), 1, 1)
		endif
	next i
endfunction

function HandleUserInput()
	if IsNetworkHost(g.LAN.netID)
		clientid = GetNetworkFirstClient(g.LAN.netID)
		while clientid <> 0
			for i = 1 to 2
				if GetNetworkClientInteger(g.LAN.netID, clientid, Str((clientid-1)*2+i))
					for taskIndex = 1 to 2
						if g.host.task[taskIndex] = (clientid-1)*2+i
							g.host.task[taskIndex] = 0
							inc g.host.socre
							SetNetworkLocalInteger(g.LAN.netID, "score", g.host.socre)
						endif
					next taskIndex
				endif
			next i
		
			clientid = GetNetworkNextClient(g.LAN.netID)
		endwhile
	endif
endfunction

function HandleOther()
	g.score = GetNetworkClientInteger(g.LAN.netID, 1, "score")
	if g.txtID = 0
		g.txtID = CreateText("Total Zombie Kills: "+Str(g.score))
		SetTextAlignment(g.txtID, 1)
		SetTextPosition(g.txtID, 50, 10)
	else
		SetTextString(g.txtID, "Total Zombie Kills: "+Str(g.score))
	endif
endfunction

