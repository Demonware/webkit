/*
 * Copyright (C) 2016 Apple Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. AND ITS CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "config.h"
#import "GameControllerGamepadProvider.h"

#if ENABLE(GAMEPAD)

#import "GameControllerGamepad.h"
#import "GamepadProviderClient.h"
#import "Logging.h"
#import <GameController/GameController.h>
#import <wtf/NeverDestroyed.h>

#import "GameControllerSoftLink.h"

namespace WebCore {

static const Seconds inputNotificationDelay { 16_ms };

GameControllerGamepadProvider& GameControllerGamepadProvider::singleton()
{
    static NeverDestroyed<GameControllerGamepadProvider> sharedProvider;
    return sharedProvider;
}

GameControllerGamepadProvider::GameControllerGamepadProvider()
    : m_inputNotificationTimer(RunLoop::current(), this, &GameControllerGamepadProvider::inputNotificationTimerFired)

{
}

void GameControllerGamepadProvider::controllerDidConnect(GCController *controller, ConnectionVisibility visibility)
{
    LOG(Gamepad, "GameControllerGamepadProvider controller %p added", controller);

    // When initially starting up the GameController framework machinery,
    // we might get the connection notification for an already-connected controller.
    if (m_gamepadMap.contains(controller))
        return;

    unsigned index = indexForNewlyConnectedDevice();
    auto gamepad = makeUnique<GameControllerGamepad>(controller, index);

    if (m_gamepadVector.size() <= index)
        m_gamepadVector.grow(index + 1);

    m_gamepadVector[index] = gamepad.get();
    m_gamepadMap.set((__bridge CFTypeRef)controller, WTFMove(gamepad));


    if (visibility == ConnectionVisibility::Invisible) {
        m_invisibleGamepads.add(m_gamepadVector[index]);
        return;
    }

    makeInvisibleGamepadsVisible();

    for (auto& client : m_clients)
        client->platformGamepadConnected(*m_gamepadVector[index], EventMakesGamepadsVisible::Yes);
}

void GameControllerGamepadProvider::controllerDidDisconnect(GCController *controller)
{
    LOG(Gamepad, "GameControllerGamepadProvider controller %p removed", controller);

    auto removedGamepad = m_gamepadMap.take((__bridge CFTypeRef)controller);
    ASSERT(removedGamepad);

    auto i = m_gamepadVector.find(removedGamepad.get());
    if (i != notFound)
        m_gamepadVector[i] = nullptr;

    m_invisibleGamepads.remove(removedGamepad.get());

    for (auto& client : m_clients)
        client->platformGamepadDisconnected(*removedGamepad);
}

void GameControllerGamepadProvider::prewarmGameControllerDevicesIfNecessary()
{
    static bool prewarmed;
    if (prewarmed)
        return;

    LOG(Gamepad, "GameControllerGamepadProvider explicitly starting GameController framework monitoring");
    [getGCControllerClass() __openXPC_and_CBApplicationDidBecomeActive__];
    prewarmed = true;
}

void GameControllerGamepadProvider::startMonitoringGamepads(GamepadProviderClient& client)
{
    ASSERT(!m_clients.contains(&client));
    m_clients.add(&client);

    if (m_connectObserver)
        return;

    prewarmGameControllerDevicesIfNecessary();

    if (canLoad_GameController_GCControllerDidConnectNotification()) {
        m_connectObserver = [[NSNotificationCenter defaultCenter] addObserverForName:get_GameController_GCControllerDidConnectNotification() object:nil queue:nil usingBlock:^(NSNotification *notification) {
            LOG(Gamepad, "GameControllerGamepadProvider notified of new GCController %p", notification.object);
            GameControllerGamepadProvider::singleton().controllerDidConnect(notification.object, ConnectionVisibility::Visible);
        }];
    }

    if (canLoad_GameController_GCControllerDidDisconnectNotification()) {
        m_disconnectObserver = [[NSNotificationCenter defaultCenter] addObserverForName:get_GameController_GCControllerDidDisconnectNotification() object:nil queue:nil usingBlock:^(NSNotification *notification) {
            LOG(Gamepad, "GameControllerGamepadProvider notified of disconnected GCController %p", notification.object);
            GameControllerGamepadProvider::singleton().controllerDidDisconnect(notification.object);
        }];
    }

    auto *controllers = [getGCControllerClass() controllers];
    if (!controllers || !controllers.count)
        LOG(Gamepad, "GameControllerGamepadProvider has no initial GCControllers attached");

    for (GCController *controller in controllers) {
        LOG(Gamepad, "GameControllerGamepadProvider has initial GCController %p", controller);
        controllerDidConnect(controller, ConnectionVisibility::Invisible);
    }
}

void GameControllerGamepadProvider::stopMonitoringGamepads(GamepadProviderClient& client)
{
    ASSERT(m_clients.contains(&client));
    m_clients.remove(&client);

    if (!m_connectObserver || !m_clients.isEmpty())
        return;

    [[NSNotificationCenter defaultCenter] removeObserver:m_connectObserver.get()];
    [[NSNotificationCenter defaultCenter] removeObserver:m_disconnectObserver.get()];
}

unsigned GameControllerGamepadProvider::indexForNewlyConnectedDevice()
{
    unsigned index = 0;
    while (index < m_gamepadVector.size() && m_gamepadVector[index])
        ++index;

    return index;
}

void GameControllerGamepadProvider::gamepadHadInput(GameControllerGamepad&, bool hadButtonPresses)
{
    if (!m_inputNotificationTimer.isActive())
        m_inputNotificationTimer.startOneShot(inputNotificationDelay);

    if (hadButtonPresses)
        m_shouldMakeInvisibleGamepadsVisible = true;
}

void GameControllerGamepadProvider::makeInvisibleGamepadsVisible()
{
    for (auto* gamepad : m_invisibleGamepads) {
        for (auto& client : m_clients)
            client->platformGamepadConnected(*gamepad, EventMakesGamepadsVisible::Yes);
    }

    m_invisibleGamepads.clear();
}

void GameControllerGamepadProvider::inputNotificationTimerFired()
{
    if (m_shouldMakeInvisibleGamepadsVisible) {
        setShouldMakeGamepadsVisibile();
        makeInvisibleGamepadsVisible();
    }

    m_shouldMakeInvisibleGamepadsVisible = false;

    dispatchPlatformGamepadInputActivity();
}

} // namespace WebCore

#endif // ENABLE(GAMEPAD)
