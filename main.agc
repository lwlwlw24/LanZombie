// Project: LanZombie
// Created: 2018-05-24

#include "../Function Lib/CoreLibrary.agc"
//#include "../Function Lib/GUILibrary.agc"
#include "../Function Lib/GUILibrary_CN.agc"
#include "../Function Lib/LanLibrary.agc"
#include "../Function Lib/HealthBar.agc"

#constant MAXTASKNUMBERHOST = 4
#constant DEFAULTTASKTIMEOUT = 4

#constant TOTALZOMBIES = 60
#constant TOTALAMMO = 40//TOTALZOMBIES * 2
#constant MAXHOUSEHP = 10 //TOTALZOMBIES *0.2

type HostDataType 
	taskList as integer[MAXTASKNUMBERHOST] // all task storage here
	taskTimeout as float[MAXTASKNUMBERHOST]
	socre as integer
	ammo as integer
	demage as integer
	timer as float
endtype

type ClientDataType
	taskItem as integer // 
	taskTimeout as float
	textID as integer
	buttons as integer[2]
	timer as float
endtype

type GameType
	score as integer
	ammo as integer
	demage as integer
	txtID as integer	//for score
	txtAmmoID as integer 
	txtDemageID as integer
	LAN as LANType
	host as HostDataType
	client as ClientDataType
	bar as HealthBarType
endtype

global taskTextList as string[8] = ["", "前窗", "前门", "左前窗", "左窗", "后门", "后窗", "侧门", "草坪"]

global g as GameType

global fontID as integer

//***************************************
//*** Main program ***
//***************************************

//SetSyncRate(30, 0)

InitialiseScreen(1024,768,"Lan Zombie", 0x28A1DE,%1111)


g.LAN = SetNetworkData("Zombie", 1026, 2, 2)
SetUpNetwork(g.LAN, "opbut.png")

GameStartPage()

LoadResources()
InitialiseGameVariables()
CreateInitialLayout()

repeat
	GetUserInput()
	HandleUserInput()
	HandleOther()
	Sync()
until CheckIfGameOver() = 1

DisplayGameOverPage()

end


//***************************************
//*** Functions ***
//***************************************

function GameStartPage()
	button as integer
	gameStart as integer
	txtNoPID as integer
	//*** if this is the host,
	// update the number of players
	// wait for user tapping start
	// send Start signal to all client
	// exit
	if IsNetworkHost(g.LAN.netID)
		repeat
			if txtNoPID = 0
				txtNoPID = CreateText("Number of player: "+Str(GetNetworkNumClients(g.LAN.netID)))
				SetTextAlignment(txtNoPID, 1)
				SetTextSize(txtNoPID, 5)
				SetTextPosition(txtNoPID, 50, 25)
			else
				SetTextString(txtNoPID, "Number of players: "+Str(GetNetworkNumClients(g.LAN.netID)))
			endif
			//Print("Number of players: "+Str(GetNetworkNumClients(g.LAN.netID)))
			if GetNetworkNumClients(g.LAN.netID) >= 2
				if button = 0
					button = CreateGUIButton(40, 70, 20, 12, "opbut.png", "Start", fontID)
				else
					if HandleGUIButton(button) and gameStart = 0
						//send info the clients say game start, go next page
						SetNetworkLocalInteger(g.LAN.netID, "ifGameStarted", 1)
						gameStart = 1 
					endif
				endif
			endif
			Sync()
		until gameStart
		DeleteGUIButton(button)
		SetNetworkNoMoreClients(g.LAN.netID)
		DeleteText(txtNoPID)
	//*** if this is the client,
	//Join the network
	// wait for start signal
	// exit 
	else
		repeat
			if txtNoPID = 0
				txtNoPID = CreateText("Number of player: "+Str(GetNetworkNumClients(g.LAN.netID)))
				SetTextAlignment(txtNoPID, 1)
				SetTextSize(txtNoPID, 5)
				SetTextPosition(txtNoPID, 50, 25)
			else
				SetTextString(txtNoPID, "Number of players: "+Str(GetNetworkNumClients(g.LAN.netID)))
			endif
			if GetNetworkClientInteger(g.LAN.netID, 1, "ifGameStarted")
				gameStart = 1
			endif
			Sync()
		until gameStart
		DeleteText(txtNoPID)
	endif
	
endfunction

function InitialiseGameVariables()
	//taskTextList = ["", "Up", "Down", "Left", "Right"]
	if IsNetworkHost(g.LAN.netID)
		g.host.socre = 0
		g.host.ammo = 0
		g.host.demage = 0
		SetNetworkLocalInteger(g.LAN.netID, "score", g.host.socre)
		g.host.timer = Timer()
	endif
	g.client.timer = Timer()	
endfunction
	
function LoadResources()
	g.bar.imgBar = LoadImage("HealthBar.png")
	g.bar.imgOverLay = LoadImage("HealthBarOverLay.png")
	fontID = LoadFont("font_GB2312.ttf")
	
endfunction

function CreateInitialLayout()
	buttons as integer
	if IsNetworkHost(g.LAN.netID)
		for i = 1 to 2
			g.client.buttons[i] = CreateGUIButton(27+(i-1)*25, 70, 20, 12, "opbut.png", taskTextList[i], fontID) 
		next i
	else
		while GetNetworkNumClients(g.LAN.netID) <= 1
			Sleep(50)
		endwhile
		for i = 1 to 2
			g.client.buttons[i] = CreateGUIButton(27+(i-1)*25, 70, 20, 12, "opbut.png", taskTextList[(GetNetworkMyClientID(g.LAN.netID)-1)*2+i], fontID ) 
		next i
	endif
	
	g.bar.sizeX = 50
	g.bar.sizeY = -1
	g.bar.positionX = 25
	g.bar.positionY = 60
	g.bar.percentage = 1
	g.bar.healthMax = DEFAULTTASKTIMEOUT
	CreateHealthBar(g.bar)
	
endfunction

function UpdateTask()
	newTimeout as float
	elapseTime as float
	
	elapseTime = Timer()-g.host.timer
	g.host.timer = Timer()
	
	if IsNetworkHost(g.LAN.netID)
		//generate task if this is host
		if GetNetworkNumClients(g.LAN.netID) > 1
			if g.host.taskList.length < GetNetworkNumClients(g.LAN.netID)
				g.host.taskList.insert(0)
				g.host.taskTimeout.insert(0.0)
			endif
			for clientIndex = 1 to GetNetworkNumClients(g.LAN.netID)
				//*** check if the task is finished or just timeout, so need to refresh the task
				if g.host.taskList[clientIndex] = 0 or g.host.taskTimeout[clientIndex] < 0
					if g.host.taskTimeout[clientIndex] < 0
						inc g.host.demage
						SetNetworkLocalInteger(g.LAN.netID, "demage", g.host.demage)
					endif
					//*** assign a task and its timeout
					g.host.taskList[clientIndex] = Random(1, GetNetworkNumClients(g.LAN.netID)*2)		//assign task
					g.host.taskTimeout[clientIndex] = DEFAULTTASKTIMEOUT		//assign task timeout
					//if this is not the host, need to send task and timeout over network
					if clientIndex <> 1
						SetNetworkLocalInteger(g.LAN.netID, "task"+Str(clientIndex), g.host.taskList[clientIndex])
						SetNetworkLocalFloat(g.LAN.netID, "taskTimeout"+Str(clientIndex), g.host.taskTimeout[clientIndex], 1)
					else
						g.client.taskTimeout = g.host.taskTimeout[1]
					endif
				//*** this client just need to update the task timeout
				else
					g.host.taskTimeout[clientIndex] = g.host.taskTimeout[clientIndex] - elapseTime
				endif
				
			next clientIndex
		else 
			Print("No Client Connected")
		endif
		//this is host, get task from local task list
		g.client.taskItem = g.host.taskList[1]
	//this is a client, get task from host
	else
		g.client.taskItem = GetNetworkClientInteger(g.LAN.netID, 1, "task"+Str(GetNetworkMyClientID(g.LAN.netID)))
		newTimeout = GetNetworkClientFloat(g.LAN.netID, 1, "taskTimeout"+Str(GetNetworkMyClientID(g.LAN.netID)))
		if newTimeout <> 0
			g.client.taskTimeout = newTimeout
		endif
	endif
endfunction

function DisplayTask()
	elapseTime as float
	
	elapseTime = Timer()-g.client.timer
	g.client.timer = Timer()
	
	if g.client.textID = 0
		g.client.textID = CreateText(taskTextList[g.client.taskItem])
		SetTextFont(g.client.textID, fontID)
		SetTextAlignment(g.client.textID, 1)
		SetTextPosition(g.client.textID, 50, 25)
		SetTextColor(g.client.textID, 234, 17, 33, 0xff)
		SetTextSize(g.client.textID, 20)
	else
		SetTextString(g.client.textID,taskTextList[g.client.taskItem])
	endif
	//Print(taskTextList[g.client.taskItem])
	//display task timeout here todo
	dec g.client.taskTimeout, elapseTime
	
	if g.client.taskTimeout < 0
		g.client.taskTimeout = 0
	endif
	//Print(g.client.taskTimeout)
	g.bar.percentage = g.client.taskTimeout / g.bar.healthMax
	UpdateHealthBar(g.bar)
endfunction

function UpdateScore()
	g.score = GetNetworkClientInteger(g.LAN.netID, 1, "score")
	if g.txtID = 0
		//g.txtID = CreateText("Total Zombie Kills: "+Str(g.score))
		g.txtID = CreateText("击杀僵尸"+Str(g.score))
		SetTextFont(g.txtID, fontID)
		SetTextAlignment(g.txtID, 1)
		SetTextPosition(g.txtID, 50, 10)
	else
		SetTextString(g.txtID, "击杀僵尸"+Str(g.score))
	endif
endfunction

function updateAmmo()
	g.ammo = GetNetworkClientInteger(g.LAN.netID, 1, "ammo")
	if g.txtAmmoID = 0
		g.txtAmmoID = CreateText("剩余弹药"+Str(TOTALAMMO - g.ammo))
		SetTextFont(g.txtAmmoID, fontID)
		SetTextAlignment(g.txtAmmoID, 2)
		SetTextPosition(g.txtAmmoID, 100, 0)
	else
		SetTextString(g.txtAmmoID, "剩余弹药"+Str(TOTALAMMO - g.ammo))
	endif
endfunction

function updateDemage()
	g.demage = GetNetworkClientInteger(g.LAN.netID, 1, "demage")
	if g.txtDemageID = 0
		g.txtDemageID = CreateText("房屋寿命: "+Str(MAXHOUSEHP - g.demage))
		SetTextFont(g.txtDemageID, fontID)
		SetTextAlignment(g.txtDemageID, 1)
		SetTextPosition(g.txtDemageID, 50, 0)
	else
		if g.demage <= MAXHOUSEHP
			SetTextString(g.txtDemageID, "房屋寿命: "+Str(MAXHOUSEHP - g.demage))
		else
			SetTextColor(g.txtDemageID, 234, 17, 33, 0xFF)
			SetTextString(g.txtDemageID, "房屋彻底损坏")
		endif
	endif

endfunction

function GetUserInput()
	for buttonIndex = 1 to 2
		if HandleGUIButton(g.client.buttons[buttonIndex]) 
			SetNetworkLocalInteger(g.LAN.netID, Str((GetNetworkMyClientID(g.LAN.netID)-1)*2+buttonIndex), 1, 1)
		endif
	next buttonIndex
endfunction

function HandleUserInput()
	if IsNetworkHost(g.LAN.netID)
		clientid = GetNetworkFirstClient(g.LAN.netID)
		while clientid <> 0
			for buttonIndex = 1 to 2
				if GetNetworkClientInteger(g.LAN.netID, clientid, Str((clientid-1)*2+buttonIndex))
					inc g.host.ammo
					SetNetworkLocalInteger(g.LAN.netID, "ammo", g.host.ammo)
					for taskIndex = 1 to GetNetworkNumClients(g.LAN.netID)
						if g.host.taskList[taskIndex] = (clientid-1)*2+buttonIndex
							g.host.taskList[taskIndex] = 0
							inc g.host.socre
							SetNetworkLocalInteger(g.LAN.netID, "score", g.host.socre)
						endif
					next taskIndex
				endif
			next buttonIndex
			clientid = GetNetworkNextClient(g.LAN.netID)
		endwhile
	endif
endfunction

function HandleOther()
	UpdateTask()
	DisplayTask()
	UpdateScore()
	updateAmmo()
	updateDemage()
endfunction

function CheckIfGameOver()
	result as integer
	if g.score >= TOTALZOMBIES
		result = 1
	endif
	if g.ammo > TOTALAMMO
		result = 1
	endif
	if g.demage > MAXHOUSEHP
		result = 1
	endif
endfunction result

function DisplayGameOverPage()	
	txtID as integer
	txtID = CreateText("")
	SetTextFont(txtID, fontID)
	SetTextAlignment(txtID, 1)
	SetTextPosition(txtID, 50, 30)
	SetTextColor(txtID, 0, 0, 0, 0xAF)
	
	if g.score >= TOTALZOMBIES
		SetTextSize(txtID, 40)
		SetTextString(txtID, "胜利")
	elseif g.demage > MAXHOUSEHP
		SetTextSize(txtID, 30)
		SetTextString(txtID, "失败")
	elseif g.ammo > TOTALAMMO
		SetTextSize(txtID, 20)
		SetTextString(txtID, "没有子弹")
	endif
	Sync()
	Sleep(10000)
endfunction
