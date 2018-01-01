### Solidity学习笔记(1) — Ballot

**作者**：孔令坤，**个人主页**：https://ohyoukillkenny.github.io/

最近开始学习Solidity，开始学习写smart contract。今天开始用一个官方提供的投票合同（Ballot Contract）进行第一步的学习。

环境的安装和使用方法这里不做过多的赘述，附上两个链接，大家可以用来参考：

MetaMask配置：https://karl.tech/learning-solidity-part-1-deploy-a-contract/

Solidity配置与运行案例：https://karl.tech/learning-solidity-part-2-voting/

另外附上官方的学习代码链接：https://solidity.readthedocs.io/en/latest/solidity-by-example.html#voting

#### 1.逻辑简介

如下图所示，整个投票过程中有三个角色，其中ChairMan负责组织投票，而Voters进行投票，Proposals是本次投票中的候选人。其中，Chairman组织投票的方式为指定全部的候选人名单，并逐一赋予候选人们投票的权力。

![Roles](http://www.z4a.net/images/2018/01/01/12c442bfea71a1a6f.png)

之后，Voters开始进行投票，他们投票有两种方式，第一种简单明了，Voter直接对心仪的Proposal进行投票。

第二种方式略为复杂，类似于人大代表大会的制度，Voters可以选择信任的Voter(不能是自己)进行委托（delegate），然后由委托人进行再次委托或者直接进行投票，示意图如下图所示。其中白色的字母表示Voter拥有的票数，即官方代码中的`weight`，而红色的字母是候选人最后获得的票数，即官方代码中的`voteCount`。

![Voters](http://www.z4a.net/images/2018/01/01/ballot-voter.png)

#### 2.代码摘要

**指定候选者名单**：chairperson的初始化和指定候选者的名单是在初始化整个合同的过程中同时进行的，这确保了合同的发起人`msg.sender`就是本次投票的组织者，chairman。代码如下：

```javascript
/// Create a new ballot to choose one of `proposalNames`.
function Ballot(bytes32[] proposalNames) public {
    chairperson = msg.sender;
    voters[chairperson].weight = 1;

    // For each of the provided proposal names,
    // create a new proposal object and add it
    // to the end of the array.
    for (uint i = 0; i < proposalNames.length; i++) {
        // `Proposal({...})` creates a temporary
        // Proposal object and `proposals.push(...)`
        // appends it to the end of `proposals`.
        proposals.push(Proposal({
            name: proposalNames[i],
            voteCount: 0
        }));
    }
}
```

**赋予投票者权力**：而在给予Voters投票权力时，合同则是采用了函数。这时，为了确保只有chairperson可以赋予去权力，官方的代码中使用了Solidity特有的`require(arg)`写法：如果require函数框内的参数输入为真，函数正常运行；如果输入为假，则终止程序的运行并且返回整个函数，e.g.,`giveRightToVote()`运行前的状态。

使用require函数的优势在于这样做会比较安全，保证如果程序中某部分运行出错可以退出程序并返回到安全状态，但是同样的，require函数的使用会消耗所有提供的gas。（gas是以太坊中特有的一种概念，用于奖励矿工们对交易进行确认的行为，基本上处理数据量越大的合同，越复杂的合同会消耗越多的gas）

赋予voter权力的代码如下:

```javascript
// Give `voter` the right to vote on this ballot.
// May only be called by `chairperson`.
function giveRightToVote(address voter) public {
    require((msg.sender == chairperson) && !voters[voter].voted &&(voters[voter].weight == 0));
    voters[voter].weight = 1;
}
```

**投票者直接向候选人投票**：这部分的代码逻辑比较简单，但是值得注意的是，官方代码使用了`storage`变量的声明。Ethereum Virtual Machine有三个地方用于存储，分别是storage, memory和stack，存储开销依次递减。具体的区别可见[链接](https://ethereum.stackexchange.com/questions/1701/what-does-the-keyword-memory-do-exactly)。但是需要注意的是，本地的一些变量如`struct`, `array` 或者 `mapping` 会自动被存储在storage中。在代码中，官方使用storage变量的声明做代码简化，即当用storage申明了`sender`后，之后对`sender`各项属性的赋值会直接写入storage中，而不用每次都做`voters[msg.sender].voted = true`此类操作：

```javascript
/// Give your vote (including votes delegated to you)
/// to proposal `proposals[proposal].name`.
function vote(uint proposal) public {
    // assigns reference
    Voter storage sender = voters[msg.sender];
    require(!sender.voted);
    sender.voted = true;
    sender.vote = proposal;

    // If `proposal` is out of the range of the array,
    // this will throw automatically and revert all
    // changes.
    proposals[proposal].voteCount += sender.weight;
}
```

**投票者通过委托进行投票**：如果你理解了在逻辑简介中图例的思想，这部分的代码很容易看懂。简单来说，Voters通过选择委托人，然后通过while循环一路找到最终的委托人，之后将自己的票给到这个最终的委托人手中，由他进行操作。需要注意的是在Solidity的编程中对while语句的使用一定要小心，防止有长时间的循环导致block中的gas耗尽，程序无法得到执行。

```javascript
/// Delegate your vote to the voter `to`.
function delegate(address to) public {
    Voter storage sender = voters[msg.sender];
    require(!sender.voted);

    // Self-delegation is not allowed.
    require(to != msg.sender);

    while (voters[to].delegate != address(0)) {
        to = voters[to].delegate;
        // We found a loop in the delegation, not allowed.
        require(to != msg.sender);
    }
    sender.voted = true;
    sender.delegate = to;
    Voter storage delegate = voters[to];
    if (delegate.voted) {
        // If the delegate already voted,
        // directly add to the number of votes
        proposals[delegate.vote].voteCount += sender.weight;
    } else {
        // If the delegate did not vote yet,
        // add to her weight.
        delegate.weight += sender.weight;
    }
}
```

**统计胜者**：最后就是简单的对所有候选人的票数进行统计，然后得到最终的胜者。需用注意的是在函数后面跟着一个`view`，它的用法详见[链接](https://github.com/ethereum/solidity/issues/992)。代码如下：

```javascript
/// @dev Computes the winning proposal taking all
/// previous votes into account.
function winningProposal() public view
        returns (uint winningProposal)
{
    uint winningVoteCount = 0;
    for (uint p = 0; p < proposals.length; p++) {
        if (proposals[p].voteCount > winningVoteCount) {
            winningVoteCount = proposals[p].voteCount;
            winningProposal = p;
        }
    }
}
// Calls winningProposal() function to get the index
// of the winner contained in the proposals array and then
// returns the name of the winner
function winnerName() public view
        returns (bytes32 winnerName)
{
    winnerName = proposals[winningProposal()].name;
}
```

#### 对官方代码的优化

官方的代码中存有两个值得改进的地方，第一在于并没有设置整个投票过程中的时长，讲道理一个规范的投票需要投票发起人指定一个投票的进行时长，超过这个时间后，就无法进行继续投票。第二在于代码没有考虑平票的情况。基于这两个问题，我对官方的代码进行了简单的优化，优化的结果放在下面的链接中，另外之后我的一些笔记会陆续放到下面的链接中：

https://github.com/Ohyoukillkenny/Learn-Solidity