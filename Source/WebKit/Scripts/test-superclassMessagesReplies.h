/*
 * Copyright (C) 2010-2020 Apple Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1.  Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 * 2.  Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. AND ITS CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#pragma once

#include "MessageNames.h"
#include "TestClassName.h"
#include <wtf/Forward.h>
#include <wtf/Optional.h>


namespace Messages {
namespace WebPage {

#if ENABLE(TEST_FEATURE)
using TestAsyncMessageAsyncReply = CompletionHandler<void(uint64_t result)>;
#endif

#if ENABLE(TEST_FEATURE)
using TestAsyncMessageWithNoArgumentsAsyncReply = CompletionHandler<void()>;
#endif

#if ENABLE(TEST_FEATURE)
using TestAsyncMessageWithMultipleArgumentsAsyncReply = CompletionHandler<void(bool flag, uint64_t value)>;
#endif

#if ENABLE(TEST_FEATURE)
using TestAsyncMessageWithConnectionAsyncReply = CompletionHandler<void(bool flag)>;
#endif

using TestSyncMessageDelayedReply = CompletionHandler<void(uint8_t reply)>;

using TestSynchronousMessageDelayedReply = CompletionHandler<void(const Optional<WebKit::TestClassName>& optionalReply)>;

} // namespace WebPage
} // namespace Messages
